using JuMP
using Gurobi
using SDDP
using Plots
using Statistics
graph = SDDP.LinearGraph(100)   # Creamos 3 nodos y 3 arcos

# Construcción del subproblema para cada nodo del grafo. La primera parte del subproblema es identificar las variables de estado.
# como solo hay un estanque, solo hay una variable de estado, el volumen de la hidro [MWh].
# El volumen va entre [0, 300], parte con 100
function subproblem_builder(subproblem::Model, node::Int)
    # ... stuff to go here ...
    # Variable de estado -> Volumen de estanque 
    @variable(subproblem, 0 <= volume <= 300, SDDP.State, initial_value = 100)
    # Control variables
    @variables(subproblem, begin
        gen_termico_1 >= 0
        gen_termico_2 >= 0
        gen_termico_3 >= 0
        hydro_generation >= 0
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


num_iteraciones = 5
SDDP.train(model; iteration_limit = num_iteraciones)

simulations = SDDP.simulate(
    # The trained model to simulate.
    model,
    # The number of replications.
    100,
    # A list of names to record the values of.
    [:volume, :gen_termico_1, :gen_termico_2,:gen_termico_3,:hydro_generation, :hydro_spill],
)

vector_volumen =[]
for i in 1:100
    outgoing_volume = map(simulations[i]) do node
        push!(vector_volumen, node[:volume].out)
    end
end   

outgoing_volume = []
for i in 1:100
    lista_aux = map(simulations[i]) do node
        return node[:volume].out
    end
    push!(outgoing_volume, lista_aux)
end

#outgoing_volume[1]

# Crear un gráfico vacío con etiquetas para los ejes
plot(title="Volumen a lo largo del tiempo " * string(num_iteraciones) * " iteraciones", xlabel="Tiempo", ylabel="Volumen")

# Graficar cada columna de la matriz
for i in 1:100
    plot!(1:100, outgoing_volume[i][:], label=false)  # Agregar cada columna al gráfico
end
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


objectives = map(simulations) do simulation
    return sum(stage[:stage_objective] for stage in simulation)
end

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

