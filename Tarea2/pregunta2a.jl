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
end

function Base.show(io::IO, pronostico::Pronosticos)
    print(io, "Tecnologia: ", pronostico.Tecnologia)
end

# Ruta al archivo Excel
ruta_excel = "Tarea2/Case118.xlsx"
# Leer los datos de la hoja de cálculo en un DataFrame
xlsx_data_renovables = XLSX.readdata(ruta_excel, "Renewables", "A66:Y67")
total_renovable = [sum(xlsx_data_renovables[:, i]) for i in 2:25]
total_renovable = vcat(["Total Renovable"], total_renovable)

column_names_renovables = Vector{Any}()
# Agregar la palabra "tecnología" al vector y las horas
push!(column_names_renovables, "tecnología")
for i in 1:24
    push!(column_names_renovables, i)
end
dataframe_pronosticos_118 = DataFrame(xlsx_data_renovables[1:end, :], Symbol.(column_names_renovables))

# Agregar la fila total renovable al DataFrame
push!(dataframe_pronosticos_118, total_renovable)



pronosticos = Pronosticos[]
for fila in eachrow(dataframe_pronosticos_118)
    push!(pronosticos, Pronosticos(fila."tecnología", [value for value in fila[2:end]]))
end

n_escenarios = 100
n_horas = 24

interpolate_std(k1, k24, t) = k1 + (k24 - k1) * (t - 1) / 23
lista_kt_wind = []
lista_kt_solar = []
for i in 1:n_horas
    kt_i_wind = interpolate_std(0.147,0.3092,i)
    kt_i_sol = interpolate_std(0.1020,0.1402,i)
    push!(lista_kt_wind, kt_i_wind)
    push!(lista_kt_solar, kt_i_sol)
end

escenarios_total_wind = zeros(n_horas,n_escenarios) # Se crea una matriz de ceros con horas filas y n_escenarios columnas.
list_int_conf_90_dw = []
list_int_conf_90_up = []
list_int_conf_99_dw = []
list_int_conf_99_up = []

# Calculo escenarios total Wind #
for t in 1:n_horas
    sigma = pronosticos[1].Potencias[t]*lista_kt_wind[t]  # Pronóstico x k_t
    error = Normal(0,sigma)  # Error de pronóstico
    push!(list_int_conf_90_dw, pronosticos[1].Potencias[t] - 1.645 * sigma) 
    push!(list_int_conf_90_up, pronosticos[1].Potencias[t] + 1.645 * sigma)  
    push!(list_int_conf_99_dw, pronosticos[1].Potencias[t] - 2.575 * sigma) 
    push!(list_int_conf_99_up, pronosticos[1].Potencias[t] + 2.575 * sigma)                           
    for escenario in 1:n_escenarios
        escenarios_total_wind[t,escenario] = max(0,pronosticos[1].Potencias[t]+rand(error))
    end
end

plot()
# Iterar sobre las columnas y agregarlas al gráfico
for i in 1:size(escenarios_total_wind, 2)
    #plot!(escenarios_total_wind[:, i], label="Escenario $i", linewidth=0.5)
    plot!(escenarios_total_wind[:, i], label=nothing, linewidth=0.5)
end
plot!(pronosticos[1].Potencias, label="Valor esperado", linewidth=4, linecolor=RGB(1.0, 1.0, 0.0), linestyle=:dash)
plot!(list_int_conf_90_dw, label=nothing, linewidth=4,linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(list_int_conf_90_up, label="Int Conf 90%", linewidth=4, linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(list_int_conf_99_dw, label=nothing, linewidth=4,linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)
plot!(list_int_conf_99_up, label="Int Conf 99%", linewidth=4, linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)
# Personalizar el gráfico
xlabel!("Horas")
ylabel!("Potencia")
title!("Simulación escenarios de total eólica")
savefig("WindEscenarios.png")


# Calculo escenarios total Solar #
escenarios_total_solar = zeros(n_horas,n_escenarios)
list_int_conf_90_dw_solar = []
list_int_conf_90_up_solar = []
list_int_conf_99_dw_solar = []
list_int_conf_99_up_solar = []
for t in 1:n_horas
    sigma = pronosticos[2].Potencias[t]*lista_kt_solar[t]  # Pronóstico x k_t
    error = Normal(0,sigma)                               # Error de pronóstico
    push!(list_int_conf_90_dw_solar, pronosticos[2].Potencias[t] - 1.645 * sigma) 
    push!(list_int_conf_90_up_solar, pronosticos[2].Potencias[t] + 1.645 * sigma)  
    push!(list_int_conf_99_dw_solar, pronosticos[2].Potencias[t] - 2.575 * sigma) 
    push!(list_int_conf_99_up_solar, pronosticos[2].Potencias[t] + 2.575 * sigma)  
    for escenario in 1:n_escenarios
        escenarios_total_solar[t,escenario] = max(0,pronosticos[2].Potencias[t]+rand(error))
    end
end
plot()
# Iterar sobre las columnas y agregarlas al gráfico
for i in 1:size(escenarios_total_solar, 2)
    plot!(escenarios_total_solar[:, i], label=nothing, linewidth=0.5)
end
plot!(pronosticos[2].Potencias, label="Valor esperado", linewidth=4, linecolor=RGB(1.0, 1.0, 0.0), linestyle=:dash)
plot!(list_int_conf_90_dw_solar, label=nothing, linewidth=4,linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(list_int_conf_90_up_solar, label="Int Conf 90%", linewidth=4, linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(list_int_conf_99_dw_solar, label=nothing, linewidth=4,linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)
plot!(list_int_conf_99_up_solar, label="Int Conf 99%", linewidth=4, linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)

# Personalizar el gráfico
xlabel!("Horas")
ylabel!("Potencia")
title!("Simulación escenarios de total solar")
savefig("SolarEscenarios.png")




# Calculo escenarios total Renovable (eólico + solar) #
escenarios_total_renovable = zeros(n_horas,n_escenarios)
escenarios_total_renovable = escenarios_total_wind + escenarios_total_solar 
 
list_int_conf_90_dw_total = []
list_int_conf_90_up_total = []
list_int_conf_99_dw_total = []
list_int_conf_99_up_total = []

for t in 1:n_horas
    sigma_wind = pronosticos[1].Potencias[t]*lista_kt_wind[t] 
    sigma_solar = pronosticos[2].Potencias[t]*lista_kt_solar[t] 
    sigma_total = sigma_wind+sigma_solar
    push!(list_int_conf_90_dw_total, pronosticos[3].Potencias[t] - 1.645 * sigma_total) 
    push!(list_int_conf_90_up_total, pronosticos[3].Potencias[t] + 1.645 * sigma_total)  
    push!(list_int_conf_99_dw_total, pronosticos[3].Potencias[t] - 2.575 * sigma_total) 
    push!(list_int_conf_99_up_total, pronosticos[3].Potencias[t] + 2.575 * sigma_total)  
end

plot()
# Iterar sobre las columnas y agregarlas al gráfico
for i in 1:size(escenarios_total_renovable, 2)
    plot!(escenarios_total_renovable[:, i], label=nothing, linewidth=0.5)
end
plot!(pronosticos[3].Potencias, label="Valor esperado", linewidth=4, linecolor=RGB(1.0, 1.0, 0.0), linestyle=:dash)
plot!(list_int_conf_90_dw_total, label=nothing, linewidth=4,linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(list_int_conf_90_up_total, label="Int Conf 90%", linewidth=4, linecolor=RGB(0.0, 0.0, 1.0), linestyle=:dash)
plot!(list_int_conf_99_dw_total, label=nothing, linewidth=4,linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)
plot!(list_int_conf_99_up_total, label="Int Conf 99%", linewidth=4, linecolor=RGB(1.0, 0.0, 0.0), linestyle=:dash)

# Personalizar el gráfico
xlabel!("Horas")
ylabel!("Potencia")
title!("Simulación escenarios de total renovable")
savefig("RenovableEscenarios.png")