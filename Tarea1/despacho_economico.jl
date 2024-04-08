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
num_lineas = nrow(dataframe_lineas)

#Crear modelo despacho económico
despacho_economico = Model(Gurobi.Optimizer)
#Crear variable potencia de generador en período t
@variable(despacho_economico, Q_generacion[1:num_generadores, 1:num_periodos] >= 0)  # Cantidad que cada generador genera en cada período

#@variable(despacho_economico, flujo[1:num_barras, 1:num_periodos] >= 0) 
#Crear variable ángulo de cada barra
@variable(despacho_economico, angulo_barra[1:num_barras, 1:num_periodos] >= 0)  


#Crear variable flujo linea
@variable(despacho_economico, flujo[1:num_lineas, 1:num_periodos]) 
  

# La función objetivo es minimizar los costos de generación
@objective(despacho_economico, Min, sum(generador.GenCost * Q_generacion[generador.IdGen,tiempo] for generador in generadores for tiempo in 1:num_periodos))


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

#Restricción de demanda para cada barra y cada periodo
#=
for linea in lineas
    for tiempo in 1:num_periodos
        if tiempo == 1
            # Cálculo de la suma de la generación de los generadores conectados a la barra inicial de la línea en el tiempo t menos el flujo hacia otras barras, debe ser igual a la demanda. 
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

=#

#Restricción de relación de variables
for linea in lineas
    for t in 1:num_periodos
        @constraint(despacho_economico, flujo[linea.IdLin, t] == (angulo_barra[linea.BarIni,t] - angulo_barra[linea.BarFin,t])/linea.Imp)
    end    
end   



#Falta completar
for barra in barra_demandas
    for t in 1:num_periodos
        generacion_barra = sum(Q_generacion[gen.IdGen, t] for gen in generadores if gen.BarConexion==barra.IdBar) 
        flujos_barras = sum(flujo[lin.IdLin,t] for lin in lineas if lin.BarIni==barra.IdBar)
        if t==1
            @constraint(despacho_economico, generacion_barra - flujos_barras == barra.Dmd_t1)
        elseif t==2
            @constraint(despacho_economico, generacion_barra - flujos_barras == barra.Dmd_t2)
        elseif t==3
            @constraint(despacho_economico, generacion_barra - flujos_barras == barra.Dmd_t3)
        elseif t==4
            @constraint(despacho_economico, generacion_barra - flujos_barras == barra.Dmd_t4)
        elseif t==5
            @constraint(despacho_economico, generacion_barra - flujos_barras == barra.Dmd_t5)
        else
            @constraint(despacho_economico, generacion_barra - flujos_barras == barra.Dmd_t6) 
        end               
    end    
end    

for barra in barra_demandas
    for t in 1:num_periodos
        println("Iterando para el período: ", t)
        generacion_barra = sum(Q_generacion[gen.IdGen, t] for gen in generadores if gen.BarConexion==barra.IdBar)
        println("generacion_barra =", generacion_barra)
    end
end





# Restricción de límite de flujo por linea
for linea in lineas
    for tiempo in 1:num_periodos
        @constraint(despacho_economico, (angulo_barra[linea.BarIni, tiempo]-angulo_barra[linea.BarFin, tiempo])/linea.Imp <= linea.PotMaxLine)
    end 
end    


# Resolver el modelo
optimize!(despacho_economico)

# Verificar si el modelo es óptimo o factible
status = termination_status(despacho_economico)
if status == MOI.OPTIMAL || status == MOI.FEASIBLE_POINT
    # Obtener el valor objetivo
    costo_total = objective_value(despacho_economico)
    println("El costo total es: ", costo_total)
else
    println("El modelo no es óptimo o factible.")
end

# Obtener resultados
#generacion_optima = value.(gen)
costo_total = objective_value(despacho_economico)