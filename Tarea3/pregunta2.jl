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


num_iteraciones = 100
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

outgoing_volume[1]

# Crear un gráfico vacío con etiquetas para los ejes
plot(title="Volumen a lo largo del tiempo " * string(num_iteraciones) * " iteraciones", xlabel="Tiempo", ylabel="Volumen")

# Graficar cada columna de la matriz
for i in 1:100
    plot!(1:100, outgoing_volume[i][:], label=false)  # Agregar cada columna al gráfico
end
savefig(string(num_iteraciones) * "- iteraciones.png")
display(plot)


# Agregar otras iteraciones


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
std = std(objectives)
println("Confidence interval: ", μ, " ± ", ci)

println("Upper bound: ", μ+ci)
println("Lower bound: ", SDDP.calculate_bound(model))

#2.3
V = SDDP.ValueFunction(model; node = 1)
cost, price = SDDP.evaluate(V, Dict("volume" => 100)) # Volumen inicial 
# Costo total (N) y el costo marginal (lambda).  
# Función de costo futuros igual a 502375.0 
# Costo marginal del agua almacenada = -50, si aumento en uno el almacenamiento disminuye en 50 el costo futuro del agua. 




















# Función para ejecutar un barrido forward
function run_forward_pass(model::SDDP.PolicyGraph)
    SDDP.initialize!(model)  # Inicializar el modelo SDDP
    
    # Ejecutar un barrido forward
    while !SDDP.is_finished(model)
        SDDP.next_stage!(model)
        SDDP.optimize_current_stage!(model)
    end
    
    # Mostrar soluciones candidatas
    println("Soluciones candidatas después del barrido forward:")
    SDDP.evaluate(model, [:volume, :gen_termico_1, :gen_termico_2, :gen_termico_3, :hydro_generation, :hydro_spill])
    
    # Mostrar cortes de optimalidad y factibilidad
    println("Cortes de optimalidad después del barrido forward:")
    println(SDDP.get_optimality_cuts(model))
    println("Cortes de factibilidad después del barrido forward:")
    println(SDDP.get_feasibility_cuts(model))
end

# Función para ejecutar un barrido backward
function run_backward_pass(model::SDDP.PolicyGraph)
    while !SDDP.is_empty_backlog(model)
        SDDP.previous_stage!(model)
        SDDP.restore_solution!(model)
        SDDP.generate_cuts!(model)
    end
    
    # Mostrar soluciones candidatas después del barrido backward
    println("Soluciones candidatas después del barrido backward:")
    SDDP.evaluate(model, [:volume, :gen_termico_1, :gen_termico_2, :gen_termico_3, :hydro_generation, :hydro_spill])
    
    # Mostrar cortes de optimalidad y factibilidad después del backward
    println("Cortes de optimalidad después del barrido backward:")
    println(SDDP.get_optimality_cuts(model))
    println("Cortes de factibilidad después del barrido backward:")
    println(SDDP.get_feasibility_cuts(model))
end

# Ejecutar un barrido forward completo
run_forward_pass(model)

# Ejecutar un barrido backward completo
run_backward_pass(model)

# Ejecutar un último barrido forward completo
run_forward_pass(model)




















# Función para realizar los barridos manualmente
function perform_sweep(model)
    # Primer forward pass (1 iteración)
    println("Forward Pass 1")
    SDDP.train(model, iteration_limit = 1, log_frequency = 1)

    println("Candidate solutions after Forward Pass 1:")
    for (t, subproblem) in enumerate(model[:subproblems])
        println("Node $t:")
        print_candidate_solution(subproblem)
    end

    # Backward pass (otra iteración, total 2 iteraciones)
    println("\nBackward Pass")
    SDDP.train(model, iteration_limit = 2, log_frequency = 1)

    println("Cuts after Backward Pass:")
    for (t, subproblem) in enumerate(model[:subproblems])
        println("Node $t:")
        print_cuts(subproblem)
    end

    # Segundo forward pass (otra iteración, total 3 iteraciones)
    println("\nForward Pass 2")
    SDDP.train(model, iteration_limit = 3, log_frequency = 1)

    println("Candidate solutions after Forward Pass 2:")
    for (t, subproblem) in enumerate(model[:subproblems])
        println("Node $t:")
        print_candidate_solution(subproblem)
    end
end

# Función para imprimir las soluciones candidatas
function print_candidate_solution(subproblem)
    println("Candidate solution:")
    for v in all_variables(subproblem)
        println("$(variable_name(v)): $(JuMP.value(v))")
    end
end

# Función para imprimir los cortes de optimalidad
function print_cuts(subproblem)
    println("Cuts:")
    for cut in subproblem(node)
        println(cut)
    end
end

perform_sweep(model)
SDDP.train(model; iteration_limit = 10)

simulations = SDDP.simulate(
    # The trained model to simulate.
    model,
    # The number of replications.
    100,
    # A list of names to record the values of.
    [:volume, :gen_termico_1, :gen_termico_2, :gen_termico_3, :hydro_generation, :hydro_spill],
)

replication = 1
stage = 2
simulations[replication][stage]

outgoing_volume = map(simulations[1]) do node
    return "El volumen del estanque es: ", node[:volume].out
end

generacion_hidro = map(simulations[1]) do node
    return "Generador hidro es: ", node[:hydro_generation]
end

gen_termico_1 = map(simulations[1]) do node
    return "Generador térmico 1 produce: ", node[:gen_termico_1]
end

gen_termico_2 = map(simulations[1]) do node
    return "Generador térmico 2 produce: ", node[:gen_termico_2]
end

gen_termico_3 = map(simulations[1]) do node
    return "Generador térmico 3 produce: ", node[:gen_termico_3]
end