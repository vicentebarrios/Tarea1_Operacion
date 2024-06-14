using JuMP
using Gurobi
using Plots
using SDDP

graph = SDDP.LinearGraph(3)

# Construcción del subproblema para cada nodo del grafo. La primera parte del subproblema es identificar las variables de estado.
# como solo hay un estanque, solo hay una variable de estado, el volumen de la hidro [MWh].
# El volumen va entre [0, 300], parte con 100
function subproblem_builder(subproblem::Model, node::Int)
    # ... stuff to go here ...
    # Variable de estado -> Volumen de estanque 
    @variable(subproblem, 0 <= volume <= 200, SDDP.State, initial_value = 200)
    # Control variables
    @variables(subproblem, begin
        thermal_generation >= 0
        hydro_generation >= 0
        hydro_spill >= 0
    end)
    return subproblem
end

subproblem_builder (generic function with 1 method)

