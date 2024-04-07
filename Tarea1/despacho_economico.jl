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
    Imp::Int
end

mutable struct Demanda
    IdBar::Int
    Dmd_t1::Int
    Dmd_t2::Int
    Dmd_t3::Int
    Dmd_t4::Int
    Dmd_t5::Int
    Dmd_t6::Int  
end    


# Leer el archivo CSV y almacenar los datos en un DataFrame
dataframe_generadores = CSV.read("Generators.csv", DataFrame)
dataframe_demanda = CSV.read("Demand.csv", DataFrame)
dataframe_lineas = CSV.read("Lines.csv", DataFrame)



#ID_generadores = dataframe_generadores[:, 1]    # Se extrae la primera columna
#PotMin_generadores = dataframe_generadores[:, 2]    # Se extrae la segunda columna
#P_MAX_MW_generadores = dataframe_generadores[:, 3] 

#for valor in ID_generadores
#    println("el valor es:" * string(valor))
#end



# # Se crea un array para almacenar las instancias de Generadores
generadores = Generadores[]
for fila in eachrow(dataframe_generadores)
    # Crear una instancia de Generador para cada fila y agregarla al array
    push!(generadores, Generadores(fila.IdGen, fila.PotMin, fila.PotMax, fila.GenCost, fila.Ramp, fila.BarConexion))
end

for generador in generadores
    println("ID: ", generador.IdGen, ", Pot Min: ", generador.PotMin, ", Pot Max: ", generador.PotMax, ", Costo Generacion: ",generador.GenCost)
end   




num_generadores = nrow(dataframe_generadores)
num_periodos = ncol(dataframe_demanda)-1

for i in 1:num_periodos
    println("periodo:", i)
end    

#Crear modelo despacho económico
despacho_economico = Model(Gurobi.Optimizer)

@variable(despacho_economico, Q_generacion[1:num_generadores, 1:num_periodos] >= 0)  # Cantidad que cada generador genera en cada período


for column in eachcol(Q_generacion)
    println("primer elemento columna:", column[1])
end    

for fil in eachrow(Q_generacion)
    println("primer elemento fila :", fil[1])
end   

println("El valor es:", Q_generacion[1,1])



# La función objetivo es minimizar los costos de generación
@objective(despacho_economico, Min, sum(generador.GenCost * Q_generacion[generador.IdGen,tiempo] for generador in generadores for tiempo in 1:num_periodos))

for generador in generadores
    println("ID es:", generador.IdGen)
end

# Restricción de satisfacción de demanda    --- Falta Actualizar
@constraint(despacho_economico, sum(gen[i] for i in unidades_generacion) >= demanda)


# Restricción de límite de generación.
for gen in generadores
    for tiempo in 1:num_periodos
        @constraint(despacho_economico, gen.PotMax >= Q_generacion[gen.IdGen, tiempo] >= gen.PotMin)
    end    
end    
# El gen no va de 1,2,3 sino que va como un tipo del dato.

# Resolver el modelo
optimize!(despacho_economico)
## Holaaaaaaaaaaaaaaaaaaaaaa
println("siiuu")

println("nouuu")



# Obtener resultados
generacion_optima = value.(gen)
costo_total = objective_value(despacho_economico)