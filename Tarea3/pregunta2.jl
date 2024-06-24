using JuMP
using Gurobi
using SDDP
using Plots
using Statistics
using StatsBase
graph = SDDP.LinearGraph(100)   # Creamos 100 nodos y 100 arcos

# Construcción del subproblema para cada nodo del grafo. La primera parte del subproblema es identificar las variables de estado.
# como solo hay un estanque, solo hay una variable de estado, el volumen de la hidro [MWh].
# El volumen va entre [0, 300], parte con 100
function subproblem_builder(subproblem::Model, node::Int)
    # Variable de estado -> Volumen de estanque 
    @variable(subproblem, 0 <= volume <= 300, SDDP.State, initial_value = 100)
    # Variables de control 
    @variables(subproblem, begin
        50 >= gen_termico_1 >= 0
        50 >= gen_termico_2 >= 0
        50 >= gen_termico_3 >= 0
        150 >= hydro_generation >= 0
        hydro_spill >= 0
    end)
    # Random variables
    @variable(subproblem, inflow)
    Ω = [0.0,5.0,10.0,15.0,20.0,25.0,30.0,35.0,40.0,45.0,50.0,55.0,60.0,65.0,70.0,75.0,80.0,85.0,90.0,95.0,100.0]
    P = [0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05]
    SDDP.parameterize(subproblem, Ω, P) do ω
        return JuMP.fix(inflow, ω)
    end
    # Transition function and constraints
    @constraints(
        subproblem,
        begin
            volume.out == volume.in - hydro_generation - hydro_spill + inflow
            demand_constraint, hydro_generation + gen_termico_1 + gen_termico_2 + gen_termico_3 == 150
        end
    )
    # Stage-objective
    @stageobjective(subproblem, 50*gen_termico_1 + 100*gen_termico_2 + 150*gen_termico_3)
    return subproblem
end

model = SDDP.PolicyGraph(
    subproblem_builder,
    graph;
    sense = :Min,
    lower_bound = 0.0,
    optimizer = Gurobi.Optimizer,
)


num_iteraciones = 50
SDDP.train(model; iteration_limit = num_iteraciones)

simulations = SDDP.simulate(
    # The trained model to simulate.
    model,
    # The number of replications.
    100,
    # A list of names to record the values of.
    [:volume, :gen_termico_1, :gen_termico_2,:gen_termico_3,:hydro_generation, :hydro_spill],
)
# Access a value replication 6 and stage 3
simulations[6][2]
# Accedo a el volumen
simulations[6][90][:volume].out
typeof(simulations)

outgoing_volume = []
for i in 1:100
    lista_aux = map(simulations[i]) do node
        return node[:volume].out
    end
    push!(outgoing_volume, lista_aux)
end
mean(outgoing_volume[:][3])

#outgoing_volume[1]

# Media
promedios_etapa=[]
for etapa in 1:100
    valores_etapa= []
    for i in 1:100
        push!(valores_etapa, outgoing_volume[i][etapa])
    end
    push!(promedios_etapa, mean(valores_etapa))
end

# Calculo de percentiles
percentil_95 = []
percentil_10 = []

for etapa in 1:100
    valores_etapa= []
    for i in 1:100
        push!(valores_etapa, outgoing_volume[i][etapa])
    end
    push!(percentil_95, percentile(valores_etapa, 95))
end

for etapa in 1:100
    valores_etapa= []
    for i in 1:100
        push!(valores_etapa, outgoing_volume[i][etapa])
    end
    push!(percentil_10, percentile(valores_etapa, 10))
end


# Crear un gráfico vacío con etiquetas para los ejes
plot(title="Volumen a lo largo del tiempo " * string(num_iteraciones) * " iteraciones", xlabel="Tiempo", ylabel="Volumen")

# Graficar cada columna de la matriz
for i in 1:100
    plot!(1:100, outgoing_volume[i][:], label=false)  # Agregar cada columna al gráfico
end
plot!(1:100, promedios_etapa, label="Promedio", linecolor=:red, linewidth=2)
plot!(1:100, percentil_95, label="Percentil 95%", linecolor=:blue, linewidth=2)
plot!(1:100, percentil_10, label="Percentil 10%", linecolor=:black, linewidth=2)
savefig(string(num_iteraciones) * "- iteraciones.png")
display(plot)


#2.2

simulations = SDDP.simulate(
    # The trained model to simulate.
    model,
    # The number of replications.
    2000,
    # A list of names to record the values of.
    [:volume, :gen_termico_1, :gen_termico_2,:gen_termico_3,:hydro_generation, :hydro_spill],
)
simulations[1][1]

objectives = map(simulations) do simulation
    return sum(stage[:stage_objective] for stage in simulation)
end

outgoing_volume = []
for i in 1:100
    lista_aux = map(simulations[i]) do node
        return node[:volume].out
    end
    push!(outgoing_volume, lista_aux)
end

# Media
promedios_etapa=[]
for etapa in 1:100
    valores_etapa= []
    for i in 1:100
        push!(valores_etapa, outgoing_volume[i][etapa])
    end
    push!(promedios_etapa, mean(valores_etapa))
end


# Calculo de percentiles
percentil_95 = []
ic_95 = []

for etapa in 1:100
    valores_etapa= []
    for i in 1:100
        push!(valores_etapa, outgoing_volume[i][etapa])
    end
    push!(percentil_95, percentile(valores_etapa, 95))
end

for etapa in 1:100
    valores_etapa= []
    for i in 1:100
        push!(valores_etapa, outgoing_volume[i][etapa])
    end
    push!(ic_95, mean(valores_etapa) + 1.65*std(valores_etapa))
end

# Crear un gráfico vacío con etiquetas para los ejes
plot(title="Volumen a lo largo del tiempo " * string(num_iteraciones) * " iteraciones", xlabel="Tiempo", ylabel="Volumen")

# Graficar cada columna de la matriz
for i in 1:100
    plot!(1:100, outgoing_volume[i][:], label=false)  # Agregar cada columna al gráfico
end
plot!(1:100, promedios_etapa, label="Promedio", linecolor=:red, linewidth=2)
plot!(1:100, percentil_95, label="Percentil 95%", linecolor=:blue, linewidth=2)
plot!(1:100, ic_95, label="IC 95%", linecolor=:black, linewidth=2)
savefig(string(num_iteraciones) * "- iteraciones-IC.png")
display(plot)


lista_aux = []
for obj in objectives
    push!(lista_aux, obj)
end
std(lista_aux)
# Esto fue para comprobar que el ic que calcula SDDP es de 95%. (sigma *1,96/raiz(2000))


μ, ci = SDDP.confidence_interval(objectives)

println("Confidence interval: ", μ, " ± ", ci)

println("Upper bound: ", μ+ci)
println("Lower bound: ", SDDP.calculate_bound(model))

#2.3
V = SDDP.ValueFunction(model; node = 1)
cost, price = SDDP.evaluate(V, Dict("volume" => 100)) # Volumen inicial 
# Costo total (N) y el costo marginal (lambda).  
# Función de costo futuros igual a 502375.0 
# Costo marginal del agua almacenada = -50, si aumento en uno el almacenamiento disminuye en 50 el costo futuro del agua. 

