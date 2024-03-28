using JuMP
using Gurobi

#Crear modelo
despacho_economico = Model(Gurobi.Optimizer)

# Se definen n generadores
unidades_generacion = 1:length(costos_generacion)   #Los costos me los dan

# Variables de decisión
@variable(despacho_economico, 0 <= gen[unidades_generacion] <= capacidades_generacion)

# La función objetivo es minimizar los costos de generación
@objective(despacho_economico, Min, sum(costos_generacion[i] * gen[i] for i in unidades_generacion))

# Restricción de satisfacción de demanda
@constraint(despacho_economico, sum(gen[i] for i in unidades_generacion) >= demanda)

# Resolver el modelo
optimize!(despacho_economico)

# Obtener resultados
generacion_optima = value.(gen)
costo_total = objective_value(despacho_economico)



