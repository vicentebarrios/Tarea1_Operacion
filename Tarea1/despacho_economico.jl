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

mutable struct Lineass
    IdLin::Int
    BarIni::Int
    BarFin::Int
    PotMaxLine::Int
    Imp::Float64
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


# # Se crea un array para almacenar las instancias de Generadores
generadores = Generadores[]
for fila in eachrow(dataframe_generadores)
    # Crear una instancia de Generador para cada fila y agregarla al array
    push!(generadores, Generadores(fila.IdGen, fila.PotMin, fila.PotMax, fila.GenCost, fila.Ramp, fila.BarConexion))
end

barra_demandas = Demanda[]
for fila in eachrow(dataframe_demanda)
    # Crear una instancia de Demanda para cada fila y agregarla al array
    push!(barra_demandas, Demanda(fila.IdBar, fila.Dmd_t1, fila.Dmd_t2, fila.Dmd_t3, fila.Dmd_t4, fila.Dmd_t5, fila.Dmd_t6))
end

lineas = Lineass[]
for fila in eachrow(dataframe_lineas)
    # Crear una instancia de Demanda para cada fila y agregarla al array
    push!(lineas, Lineass(fila.IdLin, fila.BarIni, fila.BarFin, fila.PotMax, fila.Imp))
end

num_generadores = nrow(dataframe_generadores)
num_periodos = ncol(dataframe_demanda)-1
num_barras = nrow(dataframe_demanda)

for i in 1:num_periodos
    println("periodo:", i)
end    

#Crear modelo despacho económico
despacho_economico = Model(Gurobi.Optimizer)
#Crear variable potencia de generador en período t
@variable(despacho_economico, Q_generacion[1:num_generadores, 1:num_periodos] >= 0)  # Cantidad que cada generador genera en cada período

#Crear variable ángulo de cada barra
@variable(despacho_economico, angulo_barra[1:num_barras, 1:num_periodos])  


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

# Restricción #
#La suma de lo que se genera tiene que ser mayor o igual a la suma de lo que se demanda, en cada periodo
for tiempo in 1:num_periodos
    if tiempo == 1
        @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores) >= sum(demanda.Dmd_t1 for demanda in barra_demandas))
    elseif tiempo == 2
        @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores) >= sum(demanda.Dmd_t2 for demanda in barra_demandas))
    elseif tiempo == 3
        @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores) >= sum(demanda.Dmd_t3 for demanda in barra_demandas))
    elseif tiempo == 4
        @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores) >= sum(demanda.Dmd_t4 for demanda in barra_demandas))
    elseif tiempo == 5
        @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores) >= sum(demanda.Dmd_t5 for demanda in barra_demandas))
    else
        @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores) >= sum(demanda.Dmd_t6 for demanda in barra_demandas))  
    end     
end    

# Restricción de límite de generación.
for gen in generadores
    for tiempo in 1:num_periodos
        @constraint(despacho_economico, gen.PotMin <= Q_generacion[gen.IdGen, tiempo] <= gen.PotMax)
    end    
end    

#Restricción de rampas de generación
for gen in generadores
    for tiempo in 2:num_periodos
        @constraint(despacho_economico, Q_generacion[gen.IdGen, tiempo] - Q_generacion[gen.IdGen, tiempo-1] <= gen.Ramp)
    end    
end 

#Restricción de límite de potencia por línea de transmisión
for linea in lineas
    for tiempo in 1:num_periodos
        if tiempo == 1
            @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores if gen.BarConexion == linea.BarIni) - (angulo_barra[linea.BarIni, tiempo]-angulo_barra[linea.BarFin, tiempo])/linea.Imp == barra_demandas[linea.BarIni].Dmd_t1)
        elseif tiempo == 2
            @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores if gen.BarConexion == linea.BarIni) - (angulo_barra[linea.BarIni, tiempo]-angulo_barra[linea.BarFin, tiempo])/linea.Imp == barra_demandas[linea.BarIni].Dmd_t2)
        elseif tiempo == 3
            @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores if gen.BarConexion == linea.BarIni) - (angulo_barra[linea.BarIni, tiempo]-angulo_barra[linea.BarFin, tiempo])/linea.Imp == barra_demandas[linea.BarIni].Dmd_t3)
        elseif tiempo == 4  
            @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores if gen.BarConexion == linea.BarIni) - (angulo_barra[linea.BarIni, tiempo]-angulo_barra[linea.BarFin, tiempo])/linea.Imp == barra_demandas[linea.BarIni].Dmd_t4) 
        elseif tiempo == 5  
            @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores if gen.BarConexion == linea.BarIni) - (angulo_barra[linea.BarIni, tiempo]-angulo_barra[linea.BarFin, tiempo])/linea.Imp == barra_demandas[linea.BarIni].Dmd_t5) 
        else
            @constraint(despacho_economico, sum(Q_generacion[gen.IdGen, tiempo] for gen in generadores if gen.BarConexion == linea.BarIni) - (angulo_barra[linea.BarIni, tiempo]-angulo_barra[linea.BarFin, tiempo])/linea.Imp == barra_demandas[linea.BarIni].Dmd_t6)        
        end   
    end
end 

# Restricción de límite de flujo por linea
for linea in lineas
    
end    


# Resolver el modelo
optimize!(despacho_economico)
## Holaaaaaaaaaaaaaaaaaaaaaa
println("siiuu")

println("nouuu")



# Obtener resultados
generacion_optima = value.(gen)
costo_total = objective_value(despacho_economico)