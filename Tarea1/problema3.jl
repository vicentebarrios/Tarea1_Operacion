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

mutable struct Baterias
    IdBESS:: Int
    Cap:: Int
    Rend:: Float64
    BarConexion:: Int
end    

# Leer el archivo CSV y almacenar los datos en un DataFrame
dataframe_generadores = CSV.read("Generators.csv", DataFrame)
dataframe_demanda = CSV.read("Demand.csv", DataFrame)
dataframe_lineas = CSV.read("Lines.csv", DataFrame)
dataframe_baterias = CSV.read("Bess.csv", DataFrame)

## Se crean un arrays para almacenar las instancias
generadores = Generadores[]
for fila in eachrow(dataframe_generadores)
    push!(generadores, Generadores(fila.IdGen, fila.PotMin, fila.PotMax, fila.GenCost, fila.BarConexion))
end

barras = Barras[]
for fila in eachrow(dataframe_demanda)
    push!(barras, Barras(fila.IdBar, [value for value in fila[2:end]]))
end

lineas = Lineas[]
for fila in eachrow(dataframe_lineas)
    push!(lineas, Lineas(fila.IdLin, fila.BarIni, fila.BarFin, fila.PotMax, fila.Imp))
end

baterias = Baterias[]
for fila in eachrow(dataframe_baterias)
    push!(lineas, Baterias(fila.IdBESS, fila.Cap, fila.Rend, fila.BarConexion))
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
@variable(despacho_economico, pi >= angulo_barra[b in barras, t in Time_blocks] >= -pi)
@variable(despacho_economico, flujo[linea in lineas, t in Time_blocks]) 
@variable(despacho_economico, energía_bat[bateria in baterias, t in Time_blocks]) 
@variable(despacho_economico, potencia_bat[bateria in baterias, t in Time_blocks] >= 0) 



# La función objetivo es minimizar los costos de generación
@objective(despacho_economico, Min, sum(generador.GenCost * P_generador[generador,tiempo] for generador in generadores for tiempo in Time_blocks))



# Restricción de límite de generación.
@constraint(despacho_economico, constraint_Limites_gen[generador in generadores, tiempo in Time_blocks], generador.PotMin <= P_generador[generador, tiempo] <= generador.PotMax)
# Restricción de Definición flujo
@constraint(despacho_economico, constraint_flujo_linea[linea in lineas, tiempo in Time_blocks], flujo[linea, tiempo] == Potencia_base * (angulo_barra[first(a for a in barras if a.IdBar == linea.BarIni), tiempo] - angulo_barra[first(a for a in barras if a.IdBar == linea.BarFin), tiempo])/(linea.Reactancia))
# Restricción de Límite de flujo por línea
@constraint(despacho_economico, constraint_limite_flujo[linea in lineas, tiempo in Time_blocks], - linea.PotMaxLine <= flujo[linea, tiempo] <= linea.PotMaxLine)
# Restricción de Balance de potencia
@constraint(despacho_economico, constraint_Power_balance[barra in barras, tiempo in Time_blocks], sum(P_generador[generador, tiempo] for generador in generadores if generador.BarConexion == barra.IdBar) + sum(sqrt(bateria.Rend)*potencia_bat[bateria, tiempo] for bateria in baterias if bateria.BarConexion == barra.IdBar)- sum((flujo[linea, tiempo]) for linea in lineas if linea.BarIni == barra.IdBar) + sum((flujo[linea, tiempo]) for linea in lineas if linea.BarFin == barra.IdBar) == barra.Demanda[tiempo])
# Restricción barra slack, para fijar en cero el ángulo de la primera barra
@constraint(despacho_economico, constraint_barra_slack[tiempo in Time_blocks], angulo_barra[barras[1], tiempo] .== 0)
# Restricción flujo batería.
@constraint(despacho_economico, constraint_flujo_bateria[bateria in baterias, tiempo in Time_blocks], energia_bat[bateria, tiempo] == energia_bat[bateria, tiempo-1] - potencia_bat[bateria, tiempo]*sqrt(bateria.Rend) )
# Restricción Condición inicial baterias
@constraint(despacho_economico, constraint_condicion_inicial_bat[bateria in baterias], energia_bat[bateria, 0] == bateria.Cap/2 )
# Restricción Condición final baterias
@constraint(despacho_economico, constraint_condicion_final_bat[bateria in baterias], energia_bat[bateria, length(Time_blocks)] == bateria.Cap/2 )
# Restricción capacidad de energía baterias
@constraint(despacho_economico, constraint_cap_energia_bat[bateria in baterias, tiempo in Time_blocks], energia_bat[bateria, tiempo] <= bateria.Cap*3 )
# Restricción de potencia de la batería
@constraint(despacho_economico, constraint_cap_potencia_bat[bateria in baterias, tiempo in Time_blocks], potencia_bat[bateria,tiempo] <= bateria.Cap)

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
