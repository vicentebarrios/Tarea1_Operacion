using Distributions
using XLSX
using JuMP
using Gurobi
using CSV
using DataFrames
using Plots



#Creación estructura generadores
mutable struct Generadores
    Generator::String
    Bus::Int64
    Pmax::Float64
    Pmin::Float64
    Qmax::Float64
    Qmin::Float64
    Ramp::Float64
    SRamp::Float64
    MinUP::Int64
    MinDW::Int64
    InitS::Int64
    InitP::Int64
    StartUpCost::Int64
    FixedCost::Float64
    VariableCost::Float64
    Type::String
    PMinFactor::Float64
    QFactor::Float64
    RampFactor::Float64
    StartUpCostFactor::Int64
end

function Base.show(io::IO, generador::Generadores)
    print(io, "Gen: ", generador.Generator)
end

mutable struct Pronosticos
    Tecnologia::String15
    Potencias::Vector{Float64}
    z_90::Vector{Float64}
    z_99::Vector{Float64}
end

function Base.show(io::IO, pronostico::Pronosticos)
    print(io, "Tecnologia: ", pronostico.Tecnologia)
end

mutable struct Pronosticos_escenarios
    Tecnologia::String15
    Escenario::Int64
    Potencias::Vector{Float64}
end

function Base.show(io::IO, pronostico::Pronosticos_escenarios)
    print(io, "Tecnologia: ", pronostico.Tecnologia)
end



mutable struct Lineas
    BranchName::String15
    FromBus::Int64
    ToBus::Int64
    Resistence::Float64
    Reactance::Float64
    LineCharging::Int64
    MaxFlow::Int64
end

function Base.show(io::IO, linea::Lineas)
    print(io, "Linea: ", linea.BranchName)
end

mutable struct Barras
    IdBar::Int64
    Demanda::Vector{Float64}
end

function Base.show(io::IO, barra::Barras)
    print(io, "IdBar: ", barra.IdBar)
end






# Ruta al archivo Excel
ruta_excel = "Tarea2/Case118.xlsx"

# Leer los datos de la hoja de cálculo en un DataFrame
dataframe_generadores_118 = DataFrame(XLSX.readtable(ruta_excel, "Generators"))
xlsx_data_demanda = XLSX.readdata(ruta_excel, "Demand", "A2:Y120")
column_names_demanda = xlsx_data_demanda[1, :]
# Create DataFrame excluding the first row
dataframe_demanda_118 = DataFrame(xlsx_data_demanda[2:end, :], Symbol.(column_names_demanda))
dataframe_lineas_118 = DataFrame(XLSX.readtable(ruta_excel, "Lines"))
#dataframe_buses_118 = DataFrame(XLSX.readtable(ruta_excel, "Buses"))
xlsx_data_renovables = XLSX.readdata(ruta_excel, "Renewables", "A2:Y62")
column_names_renovables = xlsx_data_renovables[1, :]
dataframe_pronosticos_118 = DataFrame(xlsx_data_renovables[2:end, :], Symbol.(column_names_renovables))


#println("Primero: ", dataframe_generadores_118."Pmax [MW]"[2])
#println(names(dataframe_generadores_118))
#println("Es de tipo:", typeof(dataframe_generadores_118."PminFactor"[1]))
## Se crean un arrays para almacenar las instancias

generadores = Generadores[]
for fila in eachrow(dataframe_generadores_118)
    if fila.Generator != "END"
        push!(generadores, Generadores(fila.Generator, fila.Bus, fila."Pmax [MW]", fila."Pmin [MW]", fila."Qmax [MVAR]",fila."Qmin [MVAR]", fila."Ramp [MW/h]", fila."SRamp [MW]", fila."MinUP", fila."MinDW", fila."InitS", fila."InitP", fila."StartUpCost [\$]", fila."FixedCost [\$]", fila."VariableCost [\$/MWh]", fila."Type", fila."PminFactor", fila."QFactor", fila."RampFactor", fila."StartUpCostFactor"))
    end
end

barras = Barras[]
for fila in eachrow(dataframe_demanda_118)
    push!(barras, Barras(fila."Bus/Hour", [value for value in fila[2:end]]))
end

lineas = Lineas[]
for fila in eachrow(dataframe_lineas_118)
    if (fila."Branch Name" != "END")
        push!(lineas, Lineas(fila."Branch Name", fila."FromBus", fila."ToBus", fila."Resistance (R)", fila."Reactance (X)", fila."LineCharging (B)", fila."Max Flow [MW]"))
    end
end

#parametros
n_escenarios = 100
n_horas = 24


#Se carga info al struct

pronosticos = Pronosticos[]
for fila in eachrow(dataframe_pronosticos_118)
    push!(pronosticos, Pronosticos(fila."Gen/Hour", [value for value in fila[2:end]], [], []))
end

pronosticos_escenarios = Pronosticos_escenarios[]
for fila in eachrow(dataframe_pronosticos_118)
    for escenario in 1:n_escenarios
        push!(pronosticos_escenarios, Pronosticos_escenarios(fila."Gen/Hour", escenario, []))
    end
end

Time_blocks = [time for time in 1:(ncol(dataframe_demanda_118)-1)]
Time_Aux = [time for time in (minimum([generador.InitS for generador in generadores])+1):(ncol(dataframe_demanda_118)-1)]  #Time_Aux parte de -8 para contabilizar tiempo hacia atras.
Potencia_base = 100 #MVA



# Cálculo kt #

interpolate_std(k1, k24, t) = k1 + (k24 - k1) * (t - 1) / 23
lista_kt_wind = []
lista_kt_solar = []
for i in 1:n_horas
    kt_i_wind = interpolate_std(0.147,0.3092,i)
    kt_i_sol = interpolate_std(0.1020,0.1402,i)
    push!(lista_kt_wind, kt_i_wind)
    push!(lista_kt_solar, kt_i_sol)
end


# Calculo escenarios #
for tecnologia in pronosticos
    #eolica
    if startswith(tecnologia.Tecnologia,"W")
        for t in 1:n_horas
            sigma = tecnologia.Potencias[t]*lista_kt_wind[t]  # Pronóstico x k_t
            error = Normal(0,sigma)  # Error de pronóstico
            push!(tecnologia.z_90, 1.645 * sigma)
            push!(tecnologia.z_99, 2.575 * sigma)
            for pronostico_escenario in pronosticos_escenarios
                if pronostico_escenario.Tecnologia == tecnologia.Tecnologia
                    for escenario in 1:n_escenarios
                        if escenario == pronostico_escenario.Escenario
                            push!(pronostico_escenario.Potencias, max(0,tecnologia.Potencias[t]+rand(error)))
                        end
                    end
                end
            end
        end

    #solar
    elseif startswith(tecnologia.Tecnologia,"S")
        for t in 1:n_horas
            sigma = tecnologia.Potencias[t]*lista_kt_solar[t]  # Pronóstico x k_t
            error = Normal(0,sigma)  # Error de pronóstico
            push!(tecnologia.z_90, 1.645 * sigma)
            push!(tecnologia.z_99, 2.575 * sigma)
            for pronostico_escenario in pronosticos_escenarios
                if pronostico_escenario.Tecnologia == tecnologia.Tecnologia
                    for escenario in 1:n_escenarios
                        if escenario == pronostico_escenario.Escenario
                            push!(pronostico_escenario.Potencias, max(0,tecnologia.Potencias[t]+rand(error)))
                        end
                    end
                end
            end
        end
    end
end



#Creación de reservas
#Por ser distribución normal Reserva up = Reserva down por simetria


Reserva_90 = 1.645*(sum([(pronostico.z_90).^2 for pronostico in pronosticos]/(1.645^2), dims = 1)[1].^(1/2))
Reserva_99 = 2.575*(sum([(pronostico.z_99).^2 for pronostico in pronosticos]/(2.575^2), dims = 1)[1].^(1/2))




    #######################
    ### Creación Modelo ###
    #######################



#Crear modelo unit_commitment.
unit_commitment = Model(Gurobi.Optimizer)

# Set the relative gap
set_optimizer_attribute(unit_commitment, "MIPGap", 1e-3)

# Habilitar el registro de mensajes de Gurobi para ver el progreso
set_optimizer_attribute(unit_commitment, "OutputFlag", 1) # Esto habilita la salida de mensajes

#Creación de variables
@variable(unit_commitment, P_generador[g in generadores, t in Time_blocks] >= 0)
@variable(unit_commitment, pi >= angulo_barra[b in barras, t in Time_blocks] >= -pi)
@variable(unit_commitment, flujo[linea in lineas, t in Time_blocks]) 
#Variables de reserva
@variable(unit_commitment, reserva_gen[generador in generadores[1:54], t in Time_blocks])
# Variables binarias
@variable(unit_commitment, up_gen[g in generadores, t in Time_blocks], Bin)
@variable(unit_commitment, off_gen[g in generadores, t in Time_blocks], Bin)
@variable(unit_commitment, estado_gen[g in generadores, t in Time_Aux], Bin)

# La función objetivo es minimizar los costos de generación
@objective(unit_commitment, Min, sum(generador.VariableCost * P_generador[generador,tiempo] + generador.FixedCost * estado_gen[generador, tiempo] + generador.StartUpCost * up_gen[generador, tiempo] for generador in generadores for tiempo in Time_blocks))

# Restricción de límite inferior de generación para generadores 
@constraint(unit_commitment, Lim_gen_min[generador in generadores , tiempo in Time_blocks], P_generador[generador , tiempo] >= generador.Pmin * estado_gen[generador , tiempo])
# Restricción de límite superior de generación para generadores 
@constraint(unit_commitment, Lim_gen_max[generador in generadores, tiempo in Time_blocks], P_generador[generador, tiempo] <= generador.Pmax * estado_gen[generador, tiempo])
# Restricción de relación variable de encendido y apagado.
@constraint(unit_commitment, estados[generador in generadores, tiempo in Time_blocks], up_gen[generador, tiempo]-off_gen[generador, tiempo] == estado_gen[generador, tiempo] - estado_gen[generador, tiempo-1])
# Restricción de rampas de generación, considerando encendido de generador
@constraint(unit_commitment, Rampa_encendido[generador in generadores, tiempo in Time_blocks[2:end]], P_generador[generador, tiempo] - P_generador[generador, tiempo-1] <= generador.Ramp * (1- up_gen[generador, tiempo]) + generador.SRamp * up_gen[generador, tiempo])
# Restricción de rampas de generación, considerando apagado de generador
@constraint(unit_commitment, Rampa_apagado[generador in generadores, tiempo in Time_blocks[2:end]], - generador.SRamp * off_gen[generador, tiempo] -generador.Ramp*(1-off_gen[generador, tiempo]) <= P_generador[generador, tiempo] - P_generador[generador, tiempo-1])
# Restricción de que los generadores llevan suficiente tiempo apagado para que sean encendidos en t=1.
@constraint(unit_commitment, est_ini[generador in generadores, tiempo in Time_Aux[1:-1*minimum([generador.InitS for generador in generadores])]], estado_gen[generador, tiempo] == 0)
# Restricción de mínimo tiempo de encendido
@constraint(unit_commitment, min_t_on[generador in generadores, tiempo in Time_blocks], sum(estado_gen[generador, t] for t in Time_Aux[(tiempo-minimum([generador.InitS for generador in generadores])-generador.MinUP):(tiempo-minimum([generador.InitS for generador in generadores])-1)]) >= generador.MinUP * off_gen[generador, tiempo])
# Restricción de mínimo tiempo de apagado
@constraint(unit_commitment, min_t_off[generador in generadores, tiempo in Time_blocks], sum((1-estado_gen[generador, t]) for t in Time_Aux[(tiempo-minimum([generador.InitS for generador in generadores])-generador.MinDW):(tiempo-minimum([generador.InitS for generador in generadores])-1)]) >= generador.MinDW * up_gen[generador, tiempo])
# Definición flujo
@constraint(unit_commitment, flujo_linea[linea in lineas, tiempo in Time_blocks], flujo[linea, tiempo] == Potencia_base * (angulo_barra[first(a for a in barras if a.IdBar == linea.FromBus), tiempo] - angulo_barra[first(a for a in barras if a.IdBar == linea.ToBus), tiempo])/(linea.Reactance))
# Límite de flujo por línea
@constraint(unit_commitment, limite_flujo[linea in lineas, tiempo in Time_blocks], - linea.MaxFlow <= flujo[linea, tiempo] <= linea.MaxFlow)
# Balance de potencia
@constraint(unit_commitment, Power_balance[barra in barras, tiempo in Time_blocks], sum(P_generador[generador, tiempo] for generador in generadores if generador.Bus == barra.IdBar) - sum((flujo[linea, tiempo]) for linea in lineas if linea.FromBus == barra.IdBar) + sum((flujo[linea, tiempo]) for linea in lineas if linea.ToBus == barra.IdBar) == barra.Demanda[tiempo])
# Reserva up
@constraint(unit_commitment, Const_Reserva_up[generador in generadores[1:54], tiempo in Time_blocks], generador.Pmax * estado_gen[generador, tiempo] >= P_generador[generador, tiempo] + reserva_gen[generador, tiempo])
# Reserva down
@constraint(unit_commitment, Const_Reserva_dw[generador in generadores[1:54], tiempo in Time_blocks], generador.Pmin * estado_gen[generador, tiempo] <= P_generador[generador, tiempo] - reserva_gen[generador, tiempo])
# Suma Reserva
@constraint(unit_commitment, Suma_Reserva[tiempo in Time_blocks], Reserva_99[tiempo] <= sum(reserva_gen[generador, tiempo] for generador in generadores if startswith(generador.Generator, "G")))
# Restricción de generación de renovables cumpla con pronostico
@constraint(unit_commitment, forecast[pronostico in pronosticos, tiempo in Time_blocks], sum(P_generador[generador, tiempo] for generador in generadores if generador.Generator == pronostico.Tecnologia) <= pronostico.Potencias[tiempo])
# Restricción para fijar en cero el ángulo de la primera barra
@constraint(unit_commitment, barra_slack[tiempo in Time_blocks], angulo_barra[barras[1], tiempo] .== 0)

# Resolver el modelo
optimize!(unit_commitment)

print(termination_status(unit_commitment))

variable_cost = 0
no_load_cost = 0
start_cost = 0

if termination_status(unit_commitment) == MOI.OPTIMAL
    # Obtener los valores de las variables
    for generador in generadores
        for tiempo in Time_blocks
        #println("P_generador del generador ", generador.Generator," en el tiempo ", tiempo ," es: ", value.(P_generador[generador, tiempo]))
        println("Estado del generador ", generador.Generator," en el tiempo ", tiempo ," es: ", value.(estado_gen[generador, tiempo]))
        global variable_cost = variable_cost + generador.VariableCost * value.(P_generador[generador,tiempo])
        global no_load_cost = no_load_cost + generador.FixedCost * value.(estado_gen[generador, tiempo])
        global start_cost = start_cost + generador.StartUpCost * value.(up_gen[generador, tiempo])
        end
    end
    for linea in lineas
        for tiempo in Time_blocks
        #println("Flujo de la línea ", linea.BranchName," en el tiempo ", tiempo ," es: ", value.(flujo[linea, tiempo]))
        end
    end
    for barra in barras
        for tiempo in Time_blocks
            #println("Ángulo de la barra ", barra.IdBar," en el tiempo ", tiempo ," es: ", value.(angulo_barra[barra, tiempo]))
            # Costo marginal asociado al balance de potencia en la barra
            #costo_marginal_barra = dual(Power_balance[barra, tiempo])
            #println("Costo marginal de la barra ", barra.IdBar, " en el tiempo ", tiempo, " es: ", costo_marginal_barra)
        end
    end

    costo_total = objective_value(unit_commitment)
    println("El costo variable total es: ", variable_cost)
    println("El costo de no load es: ", no_load_cost)
    println("El costo de encender generadores es: ", start_cost)
    println("El costo total del sistema es: ", costo_total)

    # Graficar demanda y generación de cada generador
    horas = 1:24  # Número de horas

    # Grafico de demanda total y potencias generadores.
    lista_demandas = []
    lista_generador_G1 = []
    lista_generador_G2 = []
    lista_generador_G3 = []
    lista_generador_G6 = []
    lista_generador_G8 = []
    lista_generador_Wind2 = []
    lista_generador_Solar8 = []

    for tiempo in Time_blocks
        demanda_barra = 0
        for barra in barras
            demanda_barra = demanda_barra + barra.Demanda[tiempo]
        end
        push!(lista_demandas, demanda_barra)

        for generador in generadores
            if generador.Generator == "G1"
                push!(lista_generador_G1, value.(P_generador[generador,tiempo]))
            elseif generador.Generator == "G2"
                push!(lista_generador_G2, value.(P_generador[generador,tiempo]))
            elseif generador.Generator == "G3"
                push!(lista_generador_G3, value.(P_generador[generador,tiempo]))  
            elseif generador.Generator == "G6"
                push!(lista_generador_G6, value.(P_generador[generador,tiempo]))  
            elseif generador.Generator == "G8"
                push!(lista_generador_G8, value.(P_generador[generador,tiempo]))  
            elseif generador.Generator == "Wind2"
                push!(lista_generador_Wind2, value.(P_generador[generador,tiempo]))  
            elseif generador.Generator == "Solar8"
                push!(lista_generador_Solar8, value.(P_generador[generador,tiempo]))            
            end
        end
    end

    # Graficar demanda y generación de cada generador
    #plot(horas, lista_demandas, label="Demanda", xlabel="Horas", ylabel="Potencia (MW)", linewidth=3)
    #plot!(horas, lista_generador_G1, label="Generador 1", linewidth=3)
    #plot!(horas, lista_generador_G2, label="Generador 2", linewidth=3)
    #plot!(horas, lista_generador_G3, label="Generador 3", linewidth=3)
    #plot!(horas, lista_generador_G6, label="Generador 6", linewidth=3)
    #plot!(horas, lista_generador_G8, label="Generador 8", linewidth=3)
    #plot!(horas, lista_generador_Wind2, label="Generador Wind2", linewidth=3)
    #plot!(horas, lista_generador_Solar8, label="Generador Solar8", linewidth=3)

    # Especificar la posición de la leyenda en el lado izquierdo
    #plot!(legend=:right)

    # Reducir el tamaño de la fuente de la leyenda
    #plot!(legendfont=font(6))  # Cambia 8 por el tamaño de fuente deseado

    #println(lista_demandas)
    #println("Lista Generador 1: ",lista_generador_G1)
    #println("Lista Generador 2: ",lista_generador_G2)
    #println("Lista Generador 3: ",lista_generador_G3)
    #println("Lista Generador 6: ",lista_generador_G6)
    #println("Lista Generador 8: ",lista_generador_G8)
    #println("Lista Generador Wind2: ",lista_generador_Wind2)
    #println("Lista Generador Solar8: ",lista_generador_Solar8)



else
    println("El modelo no pudo ser resuelto de manera óptima.")
end

# Nombres de las columnas
column_onoff = ["generador", -9, -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
dataframe_onoff= DataFrame()

# Agregar columnas vacías al DataFrame con los nombres especificados
for col_name in column_onoff
    dataframe_onoff[!, Symbol(col_name)] = Vector{Any}()
end


#Se cargan los resultados del unitcomitment

for generador in 1:size(generadores)[1]
    lista_aux = []
    push!(lista_aux, generadores[generador].Generator)
    for tiempo in 1:size(Time_Aux)[1]
        push!(lista_aux, value.(estado_gen[generadores[generador], Time_Aux[tiempo]]))
        #dataframe_onoff[generador, 1] = generadores[generador].Generator
        #dataframe_onoff[generador, 1 + tiempo] = value.(estado_gen[generadores[generador], Time_Aux[tiempo]])
    end
    push!(dataframe_onoff, lista_aux)
end

CSV.write("onoff_99.csv", dataframe_onoff)


