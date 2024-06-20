using JuMP
using Gurobi


# Parámetros del problema
demanda = [150, 150, 150]  # MW
costo_termico = [50, 100, 150]  # USD/MWh
capacidad_termica = [50, 50, 50]  # MW
capacidad_hidraulica = 150  # MW
almacenamiento_max = 300  # MWh
almacenamiento_inicial = 100  # MWh
periodos = [1,2,3]
generadores = [1,2,3]
afluentes = [
    [50],
    [25, 75],
    [25, 75]
]  # MWh
probabilidades = [
    [1.0],
    [0.5, 0.5],
    [0.5, 0.5]
]


# Función para resolver el subproblema de Benders
function crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
    subproblema = Model(Gurobi.Optimizer)
    @variable(subproblema, 0 <= generacion_hidro <= capacidad_hidraulica)
    @variable(subproblema, 0 <= generacion_termica[generador in generadores])
    @variable(subproblema, 0 <= almacenamiento_final)
    @variable(subproblema, theta)

    @constraint(subproblema, Lim_gen_termo[generador in generadores], generacion_termica[generador] <= capacidad_termica[generador])
    @constraint(subproblema, balance_potencia, sum(generacion_termica[generador] for generador in generadores) + generacion_hidro >= demanda[semana])  # Satisfacer la demanda
    @constraint(subproblema, Lim_gen_hidro_dw,  almacenamiento_final <= almacenamiento_max)
    @constraint(subproblema, Definicion_almacenamiento, almacenamiento_final == almacenamiento_inicial + afluente - generacion_hidro)

    @constraint(subproblema, corte,  M * (almacenamiento_final - almacenamiento_final_anterior) + N <= theta)

    @objective(subproblema, Min, sum(costo_termico[generador] * generacion_termica[generador] for generador in generadores) + theta)

    optimize!(subproblema)

    println("El valor objetivo es ", objective_value(subproblema))
    println("El dual es ", dual(Definicion_almacenamiento))
    println("La generación hidro es ", value(generacion_hidro))
    println("La generación P1 es ", value(generacion_termica[1]))
    println("La generación P2 es ", value(generacion_termica[2]))
    println("La generación P3 es ", value(generacion_termica[3]))
    println("Y el almacenamiento final es ", (almacenamiento_inicial + afluente - value(generacion_hidro)))
    return objective_value(subproblema), dual(Definicion_almacenamiento), value(generacion_hidro), (almacenamiento_inicial + afluente - value(generacion_hidro))
end



##BACKWARD

#Etapa 3.1
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(0,25,3,0,0,0)

#Etapa 3.2
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(0,75,3,0,0,0)

#Etapa 3.3
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(0,25,3,0,0,0)

#Etapa 3.4
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(0,75,3,0,0,0)


#Etapa 2.1
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(0,25,2,-125,8125,0)

#Etapa 2.2
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(0,75,2,-125,8125,0)


#Etapa 1
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(100,50,1,-137.5,15937.5,0)



###FORWARD
#Etapa 2.1
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(100,25,2,-125,8125,0)

#Etapa 2.2
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(100,75,2,-125,8125,0)


#Etapa 3.1
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(75,25,3,0,0,0)

#Etapa 3.2
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(75,75,3,0,0,0)

#Etapa 3.3
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(125,25,3,0,0,0)

#Etapa 3.4
#crear_subproblema(almacenamiento_inicial, afluente, semana, M, N, almacenamiento_final_anterior)
crear_subproblema(125,75,3,0,0,0)


