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
    kt_i_wind = interpolate_std(14.7,30.92,i)
    kt_i_sol = interpolate_std(10.20,14.02,i)
    push!(lista_kt_wind, kt_i_wind)
    push!(lista_kt_solar, kt_i_sol)
end

escenarios = zeros(n_horas,n_escenarios) # Se crea una matriz de ceros con horas filas y n_escenarios columnas.

for t in 1:n_horas
    sigma = forecast[t]*lista_kt_t[t]
    dist = Normal(0,sigma)
    for escenario in 1:n_escenarios
        escenarios[t,escenario] = max(0,forecast[t]+rand(dist))
    end
end

# Calculo escenarios total Wind #
for t in 1:n_horas
    sigma = pronosticos[1].Potencias[t]*lista_kt_wind[t]  # Pronóstico x k_t
    error = Normal(0,sigma)                               # Error de pronóstico
    for escenario in 1:n_escenarios
        escenarios[t,escenario] = max(0,pronosticos[1].Potencias[t]+rand(error))
    end
end


plot()
# Iterar sobre las columnas y agregarlas al gráfico
for i in 1:size(escenarios, 2)
    plot!(escenarios[:, i], label="Escenario $i", linewidth=0.5)
end
# Personalizar el gráfico
xlabel!("Horas")
ylabel!("Potencia")
title!("Escenarios de potencia eólica")

# Ajustar el tamaño de la fuente de la leyenda
#plot!(legendfont=font(2))
plot!(legend=:false)
#plot!(legend=:top, orientation=:horizontal)

savefig("WindEscenarios.png")


for t in 1:n_horas
    sigma = renovable.Potencias[t]*lista_kt_t[t]
    dist = Normal(0,sigma)
    for escenario in 1:n_escenarios
        #escenarios[t,escenario] = max(0,renovable.Potencias[t]+rand(dist))
        escenarios[reno, t,escenario] = max(0,renovable.Potencias[t]+rand(dist))
    end
end

# Crear una matriz de ceros de tres dimensiones
gen_escenarios = zeros(Float64, dim1, dim2, dim3)
typeof(gen_escenarios)
for renovable in pronosticos
    if renovable.Tecnologia == "TotalWind"
        for t in 1:n_horas
            sigma = renovable.Potencias[t]*lista_kt_t[t]
            dist = Normal(0,sigma)
            for escenario in 1:n_escenarios
                #escenarios[t,escenario] = max(0,renovable.Potencias[t]+rand(dist))
                escenarios[t,escenario] = max(0,renovable.Potencias[t]+rand(dist))
            end
        end
    end
end

