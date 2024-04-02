using JuMP
using Gurobi
using CSV
using DataFrames

#Creación estructura generadores
mutable struct Generadores
    ID::Int
    BUS::Int
    P_MAX_MW::Int
end

mutable struct Loads
    ID::Int
    BUS::Int
    Loas::Int    
end    

mutable struct Lines
    ID::Int
    BUS_FROM::Int
    BUS_TO::Int    
    X_pu::Int
    P_MAX_MW::Int
end    

# Leer el archivo CSV y almacenar los datos en un DataFrame
dataframe_generadores = CSV.read("generadores_example.csv", DataFrame)
ID_generadores = dataframe_generadores[:, 1]    # Se extrae la primera columna

for valor in ID_generadores
    println("el valor es:" * valor)
end

# # Se crea un array para almacenar las instancias de Generadores
generadores = Generadores[]

for fila in eachrow(dataframe_generadores)
    # Crear una instancia de Generador para cada fila y agregarla al array
    push!(generadores, Generadores(fila.nombre, fila.potencia, fila.tipo))
end

println(columna1[0])




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
## Holaaaaaaaaaaaaaaaaaaaaaa
println("siiuu")

println("nouuu")



# Obtener resultados
generacion_optima = value.(gen)
costo_total = objective_value(despacho_economico)

#Holaaaaaaa
#holaholaholaholaholaholaholaholaholahola





