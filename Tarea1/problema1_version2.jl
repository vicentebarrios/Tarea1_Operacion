using JuMP
using Gurobi
using CSV
using DataFrames

#Creación estructura generadores
mutable struct Generadores
    IdGen::Int
    PotMin:: Int
    PotMax::Int
    GenCost::Int
    Ramp::Int
    BarConexion::Int
end

mutable struct Lineas
    IdLin::Int
    BarIni::Int
    BarFin::Int
    PotMaxLine::Int
    Reactancia::Float64
end

mutable struct Barras
    IdBar::Int
    Demanda::Vector{Int}
end

# Leer el archivo CSV y almacenar los datos en un DataFrame
dataframe_generadores = CSV.read("Generators.csv", DataFrame)
dataframe_demanda = CSV.read("Demand.csv", DataFrame)
dataframe_lineas = CSV.read("Lines.csv", DataFrame)


## Se crean un arrays para almacenar las instancias
generadores = Generadores[]
for fila in eachrow(dataframe_generadores)
    push!(generadores, Generadores(fila.IdGen, fila.PotMin, fila.PotMax, fila.GenCost, fila.Ramp, fila.BarConexion))
end

barras = Barras[]
for fila in eachrow(dataframe_demanda)
    push!(barras, Barras(fila.IdBar, [value for value in fila[2:end]]))
end

lineas = Lineas[]
for fila in eachrow(dataframe_lineas)
    push!(lineas, Lineas(fila.IdLin, fila.BarIni, fila.BarFin, fila.PotMax, fila.Imp))
end

Time_blocks = [time for time in 1:(ncol(dataframe_demanda)-1)]

Potencia_base = 100 #MVA



    #######################
    ### Creación Modelo ###
    #######################



#Crear modelo despacho económico
despacho_economico = Model(Gurobi.Optimizer)
# Habilitar el registro de mensajes de Gurobi para ver el progreso
set_optimizer_attribute(despacho_economico, "OutputFlag", 1) # Esto habilita la salida de mensajes

#Creación de variables
@variable(despacho_economico, P_generador[g in generadores, t in Time_blocks] >= 0)
@variable(despacho_economico, 2*pi >= angulo_barra[b in barras, t in Time_blocks] >= 0)
@variable(despacho_economico, flujo[linea in lineas, t in Time_blocks]) 


# La función objetivo es minimizar los costos de generación
@objective(despacho_economico, Min, sum(generador.GenCost * P_generador[generador,tiempo] for generador in generadores for tiempo in Time_blocks))



# Restricción de límite de generación.
@constraint(despacho_economico, constraint_Limites_gen[generador in generadores, tiempo in Time_blocks], generador.PotMin <= P_generador[generador, tiempo] <= generador.PotMax)
#Restricción de rampas de generación
@constraint(despacho_economico, constraint_Rampa_gen[generador in generadores, tiempo in Time_blocks[2:end]], -generador.Ramp <= P_generador[generador, tiempo] - P_generador[generador, tiempo - 1] <= generador.Ramp)
#Definición flujo
@constraint(despacho_economico, constraint_flujo_linea[linea in lineas, tiempo in Time_blocks], flujo[linea, tiempo] == Potencia_base * (angulo_barra[first(a for a in barras if a.IdBar == linea.BarIni), tiempo] - angulo_barra[first(a for a in barras if a.IdBar == linea.BarFin), tiempo])/(linea.Reactancia))
#Límite de flujo por línea
@constraint(despacho_economico, constraint_limite_flujo[linea in lineas, tiempo in Time_blocks], - linea.PotMaxLine <= flujo[linea, tiempo] <= linea.PotMaxLine)
#Balance de potencia
@constraint(despacho_economico, constraint_Power_balance[barra in barras, tiempo in Time_blocks], sum(P_generador[generador, tiempo] for generador in generadores if generador.BarConexion == barra.IdBar) - sum((flujo[linea, tiempo]) for linea in lineas if linea.BarIni == barra.IdBar) + sum((flujo[linea, tiempo]) for linea in lineas if linea.BarFin == barra.IdBar) >= barra.Demanda[tiempo])


# Resolver el modelo
optimize!(despacho_economico)


if termination_status(despacho_economico) == MOI.OPTIMAL
    # Obtener los valores de las variables
    for generador in generadores
        for tiempo in Time_blocks
        println("P_generador del generador ", generador.IdGen," en el tiempo ", tiempo ," es: ", value.(P_generador[generador, tiempo]))
        end
    end
    for linea in lineas
        for tiempo in Time_blocks
        println("Flujo de la línea ", linea.IdLin," en el tiempo ", tiempo ," es: ", value.(flujo[linea, tiempo]))
        end
    end
    for barra in barras
        for tiempo in Time_blocks
        println("Ángulo de la barra ", barra.IdBar," en el tiempo ", tiempo ," es: ", value.(angulo_barra[barra, tiempo]))
        end
    end
    costo_total = objective_value(despacho_economico)
    println("El costo total del sistema es: ", costo_total)

else
    println("El modelo no pudo ser resuelto de manera óptima.")
end
