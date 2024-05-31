##  Código pregunta 2 a ##

using Distributions
using XLSX
using JuMP
using Gurobi
using CSV
using DataFrames
using Plots

mutable struct Pronosticos
    Tecnologia::String15
    Potencias::Vector{Float64}
    int_conf_up_90::Vector{Float64}
    int_conf_dw_90::Vector{Float64}
    int_conf_up_99::Vector{Float64}
    int_conf_dw_99::Vector{Float64}
end

function Base.show(io::IO, pronostico::Pronosticos)
    print(io, "Tecnologia: ", pronostico.Tecnologia)
end

mutable struct Pronosticos_escenarios
    Tecnologia::String15
    Escenario::Int64
    Potencias::Vector{Float64}
end

function Base.show(io::IO, pronostico::Pronosticos_escenarios)
    print(io, "Tecnologia: ", pronostico.Tecnologia)
end

# Ruta al archivo Excel
ruta_excel = "Tarea2/Case118.xlsx"

# Leer los datos de la hoja de cálculo en un DataFrame
xlsx_data_renovables = XLSX.readdata(ruta_excel, "Renewables", "A2:Y62")
column_names_renovables = xlsx_data_renovables[1, :]
dataframe_pronosticos_118 = DataFrame(xlsx_data_renovables[2:end, :], Symbol.(column_names_renovables))

#parametros
n_escenarios = 100
n_horas = 24


#Se carga info al struct

pronosticos = Pronosticos[]
for fila in eachrow(dataframe_pronosticos_118)
    push!(pronosticos, Pronosticos(fila."Gen/Hour", [value for value in fila[2:end]], [], [], [], []))
end

pronosticos_escenarios = Pronosticos_escenarios[]
for fila in eachrow(dataframe_pronosticos_118)
    for escenario in 1:n_escenarios
        push!(pronosticos_escenarios, Pronosticos_escenarios(fila."Gen/Hour", escenario, []))
    end
end




#Definición de función para obtener parámetro útil para determinar std dev
interpolate_std(k1, k24, t) = k1 + (k24 - k1) * (t - 1) / 23
lista_kt_wind = []
lista_kt_solar = []
for i in 1:n_horas
    kt_i_wind = interpolate_std(0.147,0.3092,i)
    kt_i_sol = interpolate_std(0.1020,0.1402,i)
    push!(lista_kt_wind, kt_i_wind)
    push!(lista_kt_solar, kt_i_sol)
end

#escenarios_total_wind = zeros(n_horas,n_escenarios) # Se crea una matriz de ceros con horas filas y n_escenarios columnas.
#list_int_conf_90_dw = []
#list_int_conf_90_up = []
#list_int_conf_99_dw = []
#list_int_conf_99_up = []

# Calculo escenarios #
for tecnologia in pronosticos
    #eolica
    if startswith(tecnologia.Tecnologia,"W")
        for t in 1:n_horas
            sigma = tecnologia.Potencias[t]*lista_kt_wind[t]  # Pronóstico x k_t
            error = Normal(0,sigma)  # Error de pronóstico
            push!(tecnologia.int_conf_dw_90,tecnologia.Potencias[t] - 1.645 * sigma)
            push!(tecnologia.int_conf_up_90,tecnologia.Potencias[t] + 1.645 * sigma)
            push!(tecnologia.int_conf_dw_99,tecnologia.Potencias[t] - 2.575 * sigma)
            push!(tecnologia.int_conf_up_99,tecnologia.Potencias[t] + 2.575 * sigma)
            for pronostico_escenario in pronosticos_escenarios
                if pronostico_escenario.Tecnologia == tecnologia.Tecnologia
                    for escenario in 1:n_escenarios
                        if escenario == pronostico_escenario.Escenario
                            push!(pronostico_escenario.Potencias, max(0,tecnologia.Potencias[t]+rand(error)))
                        end
                    end
                end
            end
        end

    #solar
    elseif startswith(tecnologia.Tecnologia,"S")
        for t in 1:n_horas
            sigma = tecnologia.Potencias[t]*lista_kt_solar[t]  # Pronóstico x k_t
            error = Normal(0,sigma)  # Error de pronóstico
            push!(tecnologia.int_conf_dw_90,tecnologia.Potencias[t] - 1.645 * sigma)
            push!(tecnologia.int_conf_up_90,tecnologia.Potencias[t] + 1.645 * sigma)
            push!(tecnologia.int_conf_dw_99,tecnologia.Potencias[t] - 2.575 * sigma)
            push!(tecnologia.int_conf_up_99,tecnologia.Potencias[t] + 2.575 * sigma)
            for pronostico_escenario in pronosticos_escenarios
                if pronostico_escenario.Tecnologia == tecnologia.Tecnologia
                    for escenario in 1:n_escenarios
                        if escenario == pronostico_escenario.Escenario
                            push!(pronostico_escenario.Potencias, max(0,tecnologia.Potencias[t]+rand(error)))
                        end
                    end
                end
            end
        end
    end
end



# Plot eolico
plot()
# Iterar sobre las columnas y agregarlas al gráfico
for i in 1:n_escenarios
    plot!(sum([tecnologia.Potencias for tecnologia in pronosticos_escenarios if startswith(tecnologia.Tecnologia, "W") && tecnologia.Escenario == i], dims=1), label=nothing, linewidth=0.5)
end
plot!(sum([pronostico.Potencias for pronostico in pronosticos if startswith(pronostico.Tecnologia, "W")], dims = 1), label="Valor esperado", linewidth=4, linecolor=RGB(1.0, 1.0, 0.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos if startswith(pronostico.Tecnologia, "W")], dims = 1)[1] - 1.645*(sum([(pronostico.int_conf_dw_90 - pronostico.Potencias).^2 for pronostico in pronosticos if startswith(pronostico.Tecnologia, "W")]/(1.645^2), dims = 1)[1].^(1/2)), label=nothing, linewidth=4,linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos if startswith(pronostico.Tecnologia, "W")], dims = 1)[1] + 1.645*(sum([(pronostico.int_conf_up_90 - pronostico.Potencias).^2 for pronostico in pronosticos if startswith(pronostico.Tecnologia, "W")]/(1.645^2), dims = 1)[1].^(1/2)), label="Int Conf 90%", linewidth=4, linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos if startswith(pronostico.Tecnologia, "W")], dims = 1)[1] - 2.575*(sum([(pronostico.int_conf_dw_99 - pronostico.Potencias).^2 for pronostico in pronosticos if startswith(pronostico.Tecnologia, "W")]/(2.575^2), dims = 1)[1].^(1/2)), label=nothing, linewidth=4,linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos if startswith(pronostico.Tecnologia, "W")], dims = 1)[1] + 2.575*(sum([(pronostico.int_conf_up_99 - pronostico.Potencias).^2 for pronostico in pronosticos if startswith(pronostico.Tecnologia, "W")]/(2.575^2), dims = 1)[1].^(1/2)), label="Int Conf 99%", linewidth=4, linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)
# Personalizar el gráfico
xlabel!("Horas")
ylabel!("Potencia")
title!("Simulación escenarios de total eólica")
savefig("WindEscenarios.png")

# Plot solar
plot()
# Iterar sobre las columnas y agregarlas al gráfico
for i in 1:n_escenarios
    plot!(sum([tecnologia.Potencias for tecnologia in pronosticos_escenarios if startswith(tecnologia.Tecnologia, "S") && tecnologia.Escenario == i], dims=1), label=nothing, linewidth=0.5)
end
plot!(sum([pronostico.Potencias for pronostico in pronosticos if startswith(pronostico.Tecnologia, "S")], dims = 1), label="Valor esperado", linewidth=4, linecolor=RGB(1.0, 1.0, 0.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos if startswith(pronostico.Tecnologia, "S")], dims = 1)[1] - 1.645*(sum([(pronostico.int_conf_dw_90 - pronostico.Potencias).^2 for pronostico in pronosticos if startswith(pronostico.Tecnologia, "S")]/(1.645^2), dims = 1)[1].^(1/2)), label=nothing, linewidth=4,linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos if startswith(pronostico.Tecnologia, "S")], dims = 1)[1] + 1.645*(sum([(pronostico.int_conf_up_90 - pronostico.Potencias).^2 for pronostico in pronosticos if startswith(pronostico.Tecnologia, "S")]/(1.645^2), dims = 1)[1].^(1/2)), label="Int Conf 90%", linewidth=4, linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos if startswith(pronostico.Tecnologia, "S")], dims = 1)[1] - 2.575*(sum([(pronostico.int_conf_dw_99 - pronostico.Potencias).^2 for pronostico in pronosticos if startswith(pronostico.Tecnologia, "S")]/(2.575^2), dims = 1)[1].^(1/2)), label=nothing, linewidth=4,linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos if startswith(pronostico.Tecnologia, "S")], dims = 1)[1] + 2.575*(sum([(pronostico.int_conf_up_99 - pronostico.Potencias).^2 for pronostico in pronosticos if startswith(pronostico.Tecnologia, "S")]/(2.575^2), dims = 1)[1].^(1/2)), label="Int Conf 99%", linewidth=4, linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)
# Personalizar el gráfico
xlabel!("Horas")
ylabel!("Potencia")
title!("Simulación escenarios de total solar")
savefig("SolarEscenarios.png")


# Plot total
plot()
# Iterar sobre las columnas y agregarlas al gráfico
for i in 1:n_escenarios
    plot!(sum([tecnologia.Potencias for tecnologia in pronosticos_escenarios if tecnologia.Escenario == i], dims=1), label=nothing, linewidth=0.5)
end
plot!(sum([pronostico.Potencias for pronostico in pronosticos], dims = 1), label="Valor esperado", linewidth=4, linecolor=RGB(1.0, 1.0, 0.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos], dims = 1)[1] - 1.645*(sum([(pronostico.int_conf_dw_90 - pronostico.Potencias).^2 for pronostico in pronosticos]/(1.645^2), dims = 1)[1].^(1/2)), label=nothing, linewidth=4,linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos], dims = 1)[1] + 1.645*(sum([(pronostico.int_conf_up_90 - pronostico.Potencias).^2 for pronostico in pronosticos]/(1.645^2), dims = 1)[1].^(1/2)), label="Int Conf 90%", linewidth=4, linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos], dims = 1)[1] - 2.575*(sum([(pronostico.int_conf_dw_99 - pronostico.Potencias).^2 for pronostico in pronosticos]/(2.575^2), dims = 1)[1].^(1/2)), label=nothing, linewidth=4,linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)
plot!(sum([pronostico.Potencias for pronostico in pronosticos], dims = 1)[1] + 2.575*(sum([(pronostico.int_conf_up_99 - pronostico.Potencias).^2 for pronostico in pronosticos]/(2.575^2), dims = 1)[1].^(1/2)), label="Int Conf 99%", linewidth=4, linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)
# Personalizar el gráfico
xlabel!("Horas")
ylabel!("Potencia")
title!("Simulación escenarios de total renovable")
savefig("RenovableEscenarios.png")