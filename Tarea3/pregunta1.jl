using JuMP
using Gurobi
using Plots

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

# Función para crear el modelo maestro

function crear_modelo_maestro()
    problema_maestro = Model(Gurobi.Optimizer)
    #Creación de variables
    @variable(problema_maestro, generacion_termica[1:generadores[end], 1:periodos[end]] >= 0)
    @variable(problema_maestro, generacion_hidro[1:generadores[end], 1:periodos[end]] >= 0)
    @objective(problema_maestro, Min, sum(costo_termico[j] * generacion_termica[j,i] for i in periodos for j in generadores))
    @constraint(problema_maestro, Lim_gen_termo[g in generadores, i in periodos], generacion_termica[g, i] <= capacidad_termica[i]) # Generación térmica
    @constraint(problema_maestro, Lim_gen_hidro[i in periodos], generacion_hidro[i] <= capacidad_hidraulica) # Generación térmica
    @constraint(problema_maestro, balance_potencia[semana in periodos], sum(generacion_termica[generador, semana] for generador in generadores) + generacion_hidro[semana] >= demanda[semana] )  # Satisfacer la demanda
    return modelo
end

# Función para resolver el subproblema de Benders
function resolver_subproblema(almacenamiento, afluente)
    subproblema = Model(Gurobi.Optimizer)
    @variable(subproblema, 0 <= gen_hidro_sub[semana in periodos] <= capacidad_hidraulica)  # Generación hidráulica en el subproblema
    @constraint(subproblema, Lim_gen_hidro[semana in periodos],  gen_hidro_sub[semana] <= almacenamiento + afluente)  # Restricción de almacenamiento
    @objective(subproblema, Min, 0)  # El costo variable del generador hidráulico es 0
    optimize!(subproblema)
    return value(gen_hidro_sub), dual(subproblema[:gen_hidro_sub <= almacenamiento + afluente])
end

#function hola(a,b)
#    var = [1,2,3]
#    c=a+b
#    return var
#end
#b=hola(1,1);

# Algoritmo de Benders Anidado
function algoritmo_benders()
    modelo_maestro = crear_modelo_maestro()
    cortes_optimalidad = []
    cortes_factibilidad = []
    
    for _ in 1:3  # Realizamos 3 barridos (Forward, Backwards, Forward)
        # Barrido Forward
        for semana in periodos
            for escenario in 1:length(afluentes[semana])
                afluente = afluentes[semana][escenario]
                almacenamiento = almacenamiento_inicial  # Se podría actualizar según el escenario previo
                gen_hidro_sub, lambda = resolver_subproblema(almacenamiento, afluente)
                push!(cortes_optimalidad, lambda * (gen_hidro_sub - almacenamiento - afluente))
            end
        end
        
        # Barrido Backwards (un ejemplo de uso del último elemento)
        for semana in 1:3
            ultimo_afluente = afluentes[semana][end]
            println("El último afluente para la semana $semana es: $ultimo_afluente")
            # Actualizaciones necesarias con ultimo_afluente
        end

        # Actualizamos el modelo maestro con los cortes
        for corte in cortes_optimalidad
            @constraint(modelo_maestro, corte <= 0)
        end
        optimize!(modelo_maestro)
    end
    
    return modelo_maestro
end

# Ejecutamos el algoritmo de Benders
modelo_final = algoritmo_benders()

# Visualizamos los resultados
for g in 1:3, t in 1:3
    println("Generación térmica del generador $g en el periodo $t: ", value(modelo_final[:generacion_termica[g, t]]))
end
for t in 1:3
    println("Generación hidráulica en el periodo $t: ", value(modelo_final[:generacion_hidraulica[t]]))
end
