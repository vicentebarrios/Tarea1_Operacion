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

# Habilitar el registro de mensajes de Gurobi para ver el progreso
set_optimizer_attribute(despacho_economico, "OutputFlag", 1) # Esto habilita la salida de mensajes


#Crear variable potencia de generador en período t
@variable(despacho_economico, Q_generacion[1:num_generadores, 1:num_periodos] >= 0)  # Cantidad que cada generador genera en cada período

#Crear variable ángulo de cada barra
@variable(despacho_economico, angulo_barra[1:num_barras, 1:num_periodos])  

#Crear variable flujo linea
@variable(despacho_economico, flujo[1:num_lineas, 1:num_periodos]) 
  

# La función objetivo es minimizar los costos de generación
@objective(despacho_economico, Min, sum(generador.GenCost * Q_generacion[generador.IdGen,tiempo] for generador in generadores for tiempo in 1:num_periodos))


# Restricción de límite de generación.
for gen in generadores
    for tiempo in 1:num_periodos
        @constraint(despacho_economico, gen.PotMin <= Q_generacion[gen.IdGen, tiempo] <= gen.PotMax)
    end    
end    

#Restricción de rampas de generación
for gen in generadores
    for tiempo in 2:num_periodos
        @constraint(despacho_economico, -gen.Ramp <= Q_generacion[gen.IdGen, tiempo] - Q_generacion[gen.IdGen, tiempo-1] <= gen.Ramp)
    end    
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


#Restricción de relación de variables
for linea in lineas
    for t in 1:num_periodos
        @constraint(despacho_economico, flujo[linea.IdLin, t] == (angulo_barra[linea.BarIni,t] - angulo_barra[linea.BarFin,t])/linea.Imp)
    end    
end   

# La restricción arroja vacío # Falta corroborar
for barra in barra_demandas
    for t in 1:num_periodos
        generacion_barra = generacion_barra = isempty([gen for gen in generadores if gen.BarConexion == barra.IdBar]) ? 0 : sum(Q_generacion[gen.IdGen, t] for gen in generadores if gen.BarConexion == barra.IdBar)      
        flujo_saliente = isempty([lin for lin in lineas if lin.BarIni == barra.IdBar]) ? 0 : sum(flujo[lin.IdLin, t] for lin in lineas if lin.BarIni == barra.IdBar)
        flujo_entrante = isempty([lin for lin in lineas if lin.BarFin == barra.IdBar]) ? 0 : sum(flujo[lin.IdLin, t] for lin in lineas if lin.BarFin == barra.IdBar)
        if t==1
            @constraint(despacho_economico, generacion_barra - flujo_saliente + flujo_entrante == barra.Dmd_t1)
        elseif t==2
            @constraint(despacho_economico, generacion_barra - flujo_saliente + flujo_entrante == barra.Dmd_t2)
        elseif t==3
            @constraint(despacho_economico, generacion_barra - flujo_saliente + flujo_entrante == barra.Dmd_t3)
        elseif t==4
            @constraint(despacho_economico, generacion_barra - flujo_saliente + flujo_entrante == barra.Dmd_t4)
        elseif t==5
            @constraint(despacho_economico, generacion_barra - flujo_saliente + flujo_entrante == barra.Dmd_t5)
        else
            @constraint(despacho_economico, generacion_barra - flujo_saliente + flujo_entrante == barra.Dmd_t6)
        end               
    end    
end    

# Restricción de límite de flujo por linea
for linea in lineas
    for tiempo in 1:num_periodos
        @constraint(despacho_economico, (flujo[linea.IdLin, tiempo] <= linea.PotMaxLine))
    end 
end    


# Resolver el modelo
optimize!(despacho_economico)

# Obtener resultados
# Verificar si la optimización fue exitosa
if termination_status(despacho_economico) == MOI.OPTIMAL
    # Obtener los valores de las variables
    valores_Q_generacion = value.(Q_generacion)
    valores_angulo_barra = value.(angulo_barra)
    valores_flujo = value.(flujo)
    
    # Imprimir los valores de las variables
    println("La potencia del generador 1 en t=1 es ",value.(Q_generacion[1,1]))
    println("La potencia del generador 1 en t=2 es ",value.(Q_generacion[1,2]))
    println("La potencia del generador 1 en t=3 es ",value.(Q_generacion[1,3]))
    println("La potencia del generador 1 en t=4 es ",value.(Q_generacion[1,4]))
    println("La potencia del generador 1 en t=5 es ",value.(Q_generacion[1,5]))
    println("La potencia del generador 1 en t=6 es ",value.(Q_generacion[1,6]))
    println("-----------------------------------")
    println("La potencia del generador 2 en t=1 es ",value.(Q_generacion[2,1]))
    println("La potencia del generador 2 en t=2 es ",value.(Q_generacion[2,2]))
    println("La potencia del generador 2 en t=3 es ",value.(Q_generacion[2,3]))
    println("La potencia del generador 2 en t=4 es ",value.(Q_generacion[2,4]))
    println("La potencia del generador 2 en t=5 es ",value.(Q_generacion[2,5]))
    println("La potencia del generador 2 en t=6 es ",value.(Q_generacion[2,6]))
    println("-----------------------------------")
    println("La potencia del generador 3 en t=1 es ",value.(Q_generacion[3,1]))
    println("La potencia del generador 3 en t=2 es ",value.(Q_generacion[3,2]))
    println("La potencia del generador 3 en t=3 es ",value.(Q_generacion[3,3]))
    println("La potencia del generador 3 en t=4 es ",value.(Q_generacion[3,4]))
    println("La potencia del generador 3 en t=5 es ",value.(Q_generacion[3,5]))
    println("La potencia del generador 3 en t=6 es ",value.(Q_generacion[3,6]))

    println("-----------------------------------")
    println("Flujo desde barra 1 a 2, t=1, :", value.(flujo[1,1]))
    println("Flujo desde barra 1 a 2, t=2, :", value.(flujo[1,2]))
    println("Flujo desde barra 1 a 2, t=3, :", value.(flujo[1,3]))
    println("Flujo desde barra 1 a 2, t=4, :", value.(flujo[1,4]))
    println("Flujo desde barra 1 a 2, t=5, :", value.(flujo[1,5]))
    println("Flujo desde barra 1 a 2, t=6, :", value.(flujo[1,6]))
    println("-----------------------------------")
    println("Flujo desde barra 1 a 3, t=1, :", value.(flujo[2,1]))
    println("Flujo desde barra 1 a 3, t=2, :", value.(flujo[2,2]))
    println("Flujo desde barra 1 a 3, t=3, :", value.(flujo[2,3]))
    println("Flujo desde barra 1 a 3, t=4, :", value.(flujo[2,4]))
    println("Flujo desde barra 1 a 3, t=5, :", value.(flujo[2,5]))
    println("Flujo desde barra 1 a 3, t=6, :", value.(flujo[2,6]))
    println("-----------------------------------")
    println("Flujo desde barra 2 a 4, t=1, :", value.(flujo[3,1]))
    println("Flujo desde barra 2 a 4, t=2, :", value.(flujo[3,2]))
    println("Flujo desde barra 2 a 4, t=3, :", value.(flujo[3,3]))
    println("Flujo desde barra 2 a 4, t=4, :", value.(flujo[3,4]))
    println("Flujo desde barra 2 a 4, t=5, :", value.(flujo[3,5]))
    println("Flujo desde barra 2 a 4, t=6, :", value.(flujo[3,6]))
    println("-----------------------------------")
    println("Flujo desde barra 2 a 5, t=1, :", value.(flujo[4,1]))
    println("Flujo desde barra 2 a 5, t=2, :", value.(flujo[4,2]))
    println("Flujo desde barra 2 a 5, t=3, :", value.(flujo[4,3]))
    println("Flujo desde barra 2 a 5, t=4, :", value.(flujo[4,4]))
    println("Flujo desde barra 2 a 5, t=5, :", value.(flujo[4,5]))
    println("Flujo desde barra 2 a 5, t=6, :", value.(flujo[4,6]))
    println("-----------------------------------")
    println("Flujo desde barra 3 a 6, t=1, :", value.(flujo[5,1]))
    println("Flujo desde barra 3 a 6, t=2, :", value.(flujo[5,2]))
    println("Flujo desde barra 3 a 6, t=3, :", value.(flujo[5,3]))
    println("Flujo desde barra 3 a 6, t=4, :", value.(flujo[5,4]))
    println("Flujo desde barra 3 a 6, t=5, :", value.(flujo[5,5]))
    println("Flujo desde barra 3 a 6, t=6, :", value.(flujo[5,6]))
    println("-----------------------------------")
    println("Flujo desde barra 4 a 7, t=1, :", value.(flujo[6,1]))
    println("Flujo desde barra 4 a 7, t=2, :", value.(flujo[6,2]))
    println("Flujo desde barra 4 a 7, t=3, :", value.(flujo[6,3]))
    println("Flujo desde barra 4 a 7, t=4, :", value.(flujo[6,4]))
    println("Flujo desde barra 4 a 7, t=5, :", value.(flujo[6,5]))
    println("Flujo desde barra 4 a 7, t=6, :", value.(flujo[6,6]))
    println("-----------------------------------")
    println("Flujo desde barra 5 a 8, t=1, :", value.(flujo[7,1]))
    println("Flujo desde barra 5 a 8, t=2, :", value.(flujo[7,2]))
    println("Flujo desde barra 5 a 8, t=3, :", value.(flujo[7,3]))
    println("Flujo desde barra 5 a 8, t=4, :", value.(flujo[7,4]))
    println("Flujo desde barra 5 a 8, t=5, :", value.(flujo[7,5]))
    println("Flujo desde barra 5 a 8, t=6, :", value.(flujo[7,6]))
    println("-----------------------------------")
    println("Flujo desde barra 6 a 9, t=1, :", value.(flujo[8,1]))
    println("Flujo desde barra 6 a 9, t=2, :", value.(flujo[8,2]))
    println("Flujo desde barra 6 a 9, t=3, :", value.(flujo[8,3]))
    println("Flujo desde barra 6 a 9, t=4, :", value.(flujo[8,4]))
    println("Flujo desde barra 6 a 9, t=5, :", value.(flujo[8,5]))
    println("Flujo desde barra 6 a 9, t=6, :", value.(flujo[8,6]))
    println("-----------------------------------")
    #println("Valores de angulo_barra:")
    #println(valores_angulo_barra)
    
else
    println("El modelo no pudo ser resuelto de manera óptima.")
end

costo_total = objective_value(despacho_economico);
println("El costo total del sistema es de ", costo_total)