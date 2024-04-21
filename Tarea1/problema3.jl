using JuMP
using Gurobi
using CSV
using DataFrames

#Creación estructura generadores
mutable struct Generadores
    IdGen::Int
    PotMin::Float64
    PotMax::Float64
    GenCost::Int
    BarConexion::Int
end

mutable struct Lineas
    IdLin::Int
    BarIni::Int
    BarFin::Int
    PotMaxLine::Float64
    Reactancia::Float64
end

mutable struct Barras
    IdBar::Int
    Demanda::Vector{Float64}
end

mutable struct Baterias
    IdBESS:: Int
    Cap:: Float64
    Horas:: Float64
    Rend:: Float64
    E_inicial_porcentaje:: Float64
    E_final_porcentaje:: Float64
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
    push!(baterias, Baterias(fila.IdBESS, fila.Cap, fila.Horas, fila.Rend, fila.E_inicial, fila.E_final, fila.BarConexion))
end


Time_blocks = [time for time in 1:(ncol(dataframe_demanda)-1)]
Time_Aux = [time for time in 0:(ncol(dataframe_demanda)-1)]

Potencia_base = 100; #MVA



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
@variable(despacho_economico, energia_bat[bateria in baterias, t in Time_Aux]) 
@variable(despacho_economico, P_from_bat[bateria in baterias, t in Time_blocks] >= 0)
@variable(despacho_economico, P_to_bat[bateria in baterias, t in Time_blocks] >= 0) 

for tiempo in Time_blocks
    println("El tiempo es: ", tiempo)
end    

# La función objetivo es minimizar los costos de generación
@objective(despacho_economico, Min, sum(generador.GenCost * P_generador[generador,tiempo] for generador in generadores for tiempo in Time_blocks))



# Restricción de límite de generación.
@constraint(despacho_economico, constraint_Limites_gen[generador in generadores, tiempo in Time_blocks], generador.PotMin <= P_generador[generador, tiempo] <= generador.PotMax)
# Restricción de Definición flujo
@constraint(despacho_economico, constraint_flujo_linea[linea in lineas, tiempo in Time_blocks], flujo[linea, tiempo] == Potencia_base * (angulo_barra[first(a for a in barras if a.IdBar == linea.BarIni), tiempo] - angulo_barra[first(a for a in barras if a.IdBar == linea.BarFin), tiempo])/(linea.Reactancia))
# Restricción de Límite de flujo por línea
@constraint(despacho_economico, constraint_limite_flujo[linea in lineas, tiempo in Time_blocks], - linea.PotMaxLine <= flujo[linea, tiempo] <= linea.PotMaxLine)
# Restricción de Balance de potencia
@constraint(despacho_economico, constraint_Power_balance[barra in barras, tiempo in Time_blocks], sum(P_generador[generador, tiempo] for generador in generadores if generador.BarConexion == barra.IdBar)
                                                                                                + sum(sqrt(bateria.Rend)*P_from_bat[bateria, tiempo] for bateria in baterias if bateria.BarConexion == barra.IdBar)
                                                                                                - sum(P_to_bat[bateria, tiempo] for bateria in baterias if bateria.BarConexion == barra.IdBar)
                                                                                                - sum((flujo[linea, tiempo]) for linea in lineas if linea.BarIni == barra.IdBar)
                                                                                                + sum((flujo[linea, tiempo]) for linea in lineas if linea.BarFin == barra.IdBar)
                                                                                                == barra.Demanda[tiempo])
# Restricción barra slack, para fijar en cero el ángulo de la primera barra
@constraint(despacho_economico, constraint_barra_slack[tiempo in Time_blocks], angulo_barra[barras[1], tiempo] .== 0)
# Restricción flujo batería.
@constraint(despacho_economico, constraint_flujo_bateria[bateria in baterias, tiempo in Time_blocks], energia_bat[bateria, tiempo] == energia_bat[bateria, tiempo-1] + P_to_bat[bateria, tiempo]*sqrt(bateria.Rend) - P_from_bat[bateria, tiempo])
# Restricción Condición inicial baterias
@constraint(despacho_economico, constraint_condicion_inicial_bat[bateria in baterias], energia_bat[bateria, 0] == bateria.Cap*bateria.Horas*bateria.E_inicial_porcentaje )
# Restricción Condición final baterias
@constraint(despacho_economico, constraint_condicion_final_bat[bateria in baterias], energia_bat[bateria, length(Time_blocks)] == bateria.Cap*bateria.Horas*bateria.E_final_porcentaje )
# Restricción capacidad de energía baterias
@constraint(despacho_economico, constraint_cap_energia_bat[bateria in baterias, tiempo in Time_blocks], 0 <= energia_bat[bateria, tiempo] <= bateria.Cap*bateria.Horas)
# Restricción de potencia from batería
@constraint(despacho_economico, constraint_cap_P_from_bat[bateria in baterias, tiempo in Time_blocks], P_from_bat[bateria,tiempo] <= bateria.Cap)
# Restricción de potencia to batería
@constraint(despacho_economico, constraint_cap_P_to_bat[bateria in baterias, tiempo in Time_blocks], P_to_bat[bateria,tiempo] <= bateria.Cap)
# Restricción relación P from bat y P to bat
#@constraint(despacho_economico, constraint_relacion_P_to_from_bat[bateria in baterias, tiempo in Time_blocks], P_to_bat[bateria,tiempo] * P_from_bat[bateria,tiempo] == 0)
#Esta restricción debería estar activa para que la formulación sea completa. Sin embargo, el modelo por sí solo hace que se cumpla esta restricción al optimizar.
#Por eso la desactivo, ya que esto permite obtener más fácil los costos marginales (en un problema MIP es muy difícil con Gurobi en Julia)

# Resolver el modelo
optimize!(despacho_economico)


if termination_status(despacho_economico) == MOI.OPTIMAL
    # Obtener los valores de las variables
    for generador in generadores
        for tiempo in Time_blocks
        println("P_generador del generador ", generador.IdGen," en el tiempo ", tiempo ," es: ", value.(P_generador[generador, tiempo]))
        end
        println("--------------------------------------------")
    end
    for linea in lineas
        for tiempo in Time_blocks
        println("Flujo de la línea ", linea.IdLin," en el tiempo ", tiempo ," es: ", value.(flujo[linea, tiempo]))
        end
        println("--------------------------------------------")
    end
    for barra in barras
        for tiempo in Time_blocks
        println("Ángulo de la barra ", barra.IdBar," en el tiempo ", tiempo ," es: ", value.(angulo_barra[barra, tiempo]))
        end
        println("--------------------------------------------")
    end
    for bateria in baterias
        for tiempo in Time_Aux 
        println("La bateria " ,bateria.IdBESS, " en el tiempo ", tiempo, " tiene una energía de: ", value.(energia_bat[bateria,tiempo]))
        end
        println("--------------------------------------------")
    end
    for bateria in baterias
        for tiempo in Time_blocks
        println("La potencia desde la batería ", bateria.IdBESS," en el tiempo ", tiempo ," es: ", value.(P_from_bat[bateria, tiempo]))
        println("La potencia hacia la batería ", bateria.IdBESS," en el tiempo ", tiempo ," es: ", value.(P_to_bat[bateria, tiempo]))
        end
        println("--------------------------------------------")
    end
    for barra in barras
        for tiempo in Time_blocks
            println("El costo marginal de la barra ", barra.IdBar, " en el tiempo ", tiempo, " es: ", dual(constraint_Power_balance[barra,tiempo]))
        end
        println("-------------------------------------------")
    end    
    costo_total = objective_value(despacho_economico)
    println("El costo total del sistema es: ", costo_total)

else
    println("El modelo no pudo ser resuelto de manera óptima.")
end


#fixed = despacho_economico.fixed()
##

#fixed_model = get_fixed_model(despacho_economico)