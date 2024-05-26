using JuMP
using Gurobi
using CSV
using DataFrames
using Plots
#plotlyjs()

#Creación estructura generadores
mutable struct Generadores
    Generator::String7
    Bus::String7
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
    FixedCost::Int64
    VariableCost::Int64
    Type::String7  
end

function Base.show(io::IO, generador::Generadores)
    print(io, "Gen: ", generador.Generator)
end

mutable struct Pronosticos
    Tecnologia::String7
    Potencias::Vector{Float64}
end

function Base.show(io::IO, pronostico::Pronosticos)
    print(io, "Tecnologia: ", pronostico.Tecnologia)
end

mutable struct Lineas
    BranchName::String15
    FromBus::String7
    ToBus::String7
    Resistence::Float64
    Reactance::Float64
    LineCharging::Int64
    MaxFlow::Int64
end

function Base.show(io::IO, linea::Lineas)
    print(io, "Linea: ", linea.BranchName)
end

mutable struct Barras
    IdBar::String7
    Demanda::Vector{Float64}
end

function Base.show(io::IO, barra::Barras)
    print(io, "IdBar: ", barra.IdBar)
end



# Leer el archivo CSV y almacenar los datos en un DataFrame
dataframe_generadores_014 = CSV.read("Tarea2/Generators_014.csv", DataFrame)
dataframe_demanda_014 = CSV.read("Tarea2/Demand_014.csv", DataFrame)
dataframe_lineas_014 = CSV.read("Tarea2/Lines_014.csv", DataFrame)
dataframe_buses_014 = CSV.read("Tarea2/Buses_014.csv", DataFrame)
dataframe_pronosticos_014 = CSV.read("Tarea2/Renewables_014.csv", DataFrame)
## Se crean un arrays para almacenar las instancias
generadores = Generadores[]
for fila in eachrow(dataframe_generadores_014)
    push!(generadores, Generadores(fila.Generator, fila.Bus, fila.Pmax, fila.Pmin, fila.Qmax,fila.Qmin, fila.Ramp, fila.Sramp, fila.MinUP, fila.MinDW, fila.InitS, fila.InitP, fila.StartUpCost, fila.FixedCost, fila.VariableCost, fila.Type))
end


barras = Barras[]
for fila in eachrow(dataframe_demanda_014)
    push!(barras, Barras(fila.IdBar, [value for value in fila[2:end]]))
end

lineas = Lineas[]
for fila in eachrow(dataframe_lineas_014)
    push!(lineas, Lineas(fila.IdLin, fila.FromBus, fila.ToBus, fila.Resistance, fila.Reactance, fila.LineCharging, fila.MaxFlow))
end

pronosticos = Pronosticos[]
for fila in eachrow(dataframe_pronosticos_014)
    push!(pronosticos, Pronosticos(fila.Hour, [value for value in fila[2:end]]))
end


Time_blocks = [time for time in 1:(ncol(dataframe_demanda_014)-1)]
Time_Aux = [time for time in (minimum([generador.InitS for generador in generadores])+1):(ncol(dataframe_demanda_014)-1)]  #Time_Aux parte de -8 para contabilizar tiempo hacia atras.
Potencia_base = 100 #MVA



    #######################
    ### Creación Modelo ###
    #######################



#Crear modelo unit_commitment.
unit_commitment = Model(Gurobi.Optimizer)
# Habilitar el registro de mensajes de Gurobi para ver el progreso
set_optimizer_attribute(unit_commitment, "OutputFlag", 1) # Esto habilita la salida de mensajes

#Creación de variables
@variable(unit_commitment, P_generador[g in generadores, t in Time_blocks] >= 0)
@variable(unit_commitment, pi >= angulo_barra[b in barras, t in Time_blocks] >= -pi)
@variable(unit_commitment, flujo[linea in lineas, t in Time_blocks]) 

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
        #println("Estado del generador ", generador.Generator," en el tiempo ", tiempo ," es: ", value.(estado_gen[generador, tiempo]))
        global variable_cost = variable_cost + generador.VariableCost * value.(P_generador[generador,tiempo])
        global no_load_cost = no_load_cost + generador.FixedCost * value.(estado_gen[generador, tiempo])
        global start_cost = start_cost + generador.StartUpCost * value.(up_gen[generador, tiempo])
        end
    end
    for linea in lineas
        for tiempo in Time_blocks
        println("Flujo de la línea ", linea.BranchName," en el tiempo ", tiempo ," es: ", value.(flujo[linea, tiempo]))
        end
    end
    for barra in barras
        for tiempo in Time_blocks
            println("Ángulo de la barra ", barra.IdBar," en el tiempo ", tiempo ," es: ", value.(angulo_barra[barra, tiempo]))
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
    plot(horas, lista_demandas, label="Demanda", xlabel="Horas", ylabel="Potencia (MW)", linewidth=3)
    plot!(horas, lista_generador_G1, label="Generador 1", linewidth=3)
    plot!(horas, lista_generador_G2, label="Generador 2", linewidth=3)
    plot!(horas, lista_generador_G3, label="Generador 3", linewidth=3)
    plot!(horas, lista_generador_G6, label="Generador 6", linewidth=3)
    plot!(horas, lista_generador_G8, label="Generador 8", linewidth=3)
    plot!(horas, lista_generador_Wind2, label="Generador Wind2", linewidth=3)
    plot!(horas, lista_generador_Solar8, label="Generador Solar8", linewidth=3)

    # Especificar la posición de la leyenda en el lado izquierdo
    plot!(legend=:right)

    # Reducir el tamaño de la fuente de la leyenda
    plot!(legendfont=font(6))  # Cambia 8 por el tamaño de fuente deseado

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




