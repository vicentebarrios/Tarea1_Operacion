using JuMP, GLPK


tipo_central = ["Biomasa" "Carbon" "GNL" "Petroleo" "Hidro" "Eolica" "Solar" "Geotermia" "Minihidro" "Falla"]
bloques = ["b1" "b2" "b3"] 
de_blq = Dict()
du_blq = Dict() 
du_blq["b1"] = 1200
du_blq["b2"]  = 4152
du_blq["b3"]  = 3408
de_blq["b1"] = 10234
de_blq["b2"] = 7872
de_blq["b3"] = 6299


# Datos de centrales existentes
centrales_existentes = ["Biomasa_Itahue" "Biomasa_Charrua" "Carbon_Huasco" "Carbon_Quillota" "Carbon_Coronel" "GNL_Quillota" "Petroleo_DiegodeAlmagro" "Petroleo_Cardones" "Petroleo_LosVilos" "Petroleo_Huasco" "Petroleo_PanAzucar" "Petroleo_Quillota" "Petroleo_Valparaiso" "Petroleo_RM" "Petroleo_Itahue" "Petroleo_Charrua" "Petroleo_Valdivia" "Petroleo_PtoMontt" "Hidro_Charrua" "Eolica_LosVilos" "Solar_Huasco" "Falla"]
Potencia_Neta = [60, 204, 575, 812, 806, 731, 439, 169, 203, 58, 97, 700, 71, 368, 134, 1043, 135, 139, 5571, 192, 200,10000]
Disponibilidad = [ 0.9, 0.9, 0.88, 0.88, 0.87, 0.93, 0.90, 0.90, 0.44, 0.61, 0.90, 0.92, 0.58, 0.91, 0.90, 0.92, 0.90, 0.90, 0.60, 0.25, 0.25, 1.00]
Eficienica_Planta_existente = [1,1,0.376, 0.35,0.38,0.454,0.280,0.335,0.358,0.221,0.306,0.407,0.204, 0.280,0.278,0.359,0.296, 0.361,1,1,1,1]
Precio_MWh_CV = [ 48.7, 44.5, 24.6, 27.5, 26.5, 63.5, 169.9, 148.9, 136.4, 212.3, 169.0, 114.9, 223.5, 162.1, 174.2, 132.2, 153.5, 143.9, 0.0, 10.0, 10.0, 500.0]

pot_in = Dict() #Potencia instalada
factor_planta = Dict() #Factor de planta existente
eficiencia_planta_actual = Dict() #Eficiencia de las plantas existentes
cv = Dict() #Costos variables
for i in range(1,22) 
    pot_in[centrales_existentes[i]] = Potencia_Neta[i]
    factor_planta[centrales_existentes[i]] = Disponibilidad[i]
    eficiencia_planta_actual[centrales_existentes[i]] = Eficienica_Planta_existente[i]
    cv[centrales_existentes[i]] = Precio_MWh_CV[i]
end
contaminante = Dict("Biomasa_Itahue"=> 0,"Biomasa_Charrua"=> 0, "Carbon_Huasco"=> 1, "Carbon_Quillota"=> 1,"Carbon_Coronel"=> 1, "GNL_Quillota"=> 1, "Petroleo_DiegodeAlmagro" => 1,"Petroleo_Cardones"=> 1, "Petroleo_LosVilos"=> 1, "Petroleo_Huasco" => 1,"Petroleo_PanAzucar"=> 1, "Petroleo_Quillota" => 1,"Petroleo_Valparaiso"=> 1, "Petroleo_RM"=> 1, "Petroleo_Itahue" => 1,"Petroleo_Charrua" => 1,"Petroleo_Valdivia" => 1,"Petroleo_PtoMontt"=> 1, "Hidro_Charrua"=> 0, "Eolica_LosVilos"=> 0, "Solar_Huasco"=> 0, "Falla"=> 0, "N_Carbon_DiegodeAlmagro" => 1,"N_Carbon_Huasco"=> 1, "N_Carbon_Quillota"=> 1,"N_Carbon_RM"=> 1, "N_Carbon_Coronel" => 1,"N_Carbon_PtoMontt" => 1,"N_GNL_Quillota" => 1,"N_Hidro_Charrua"=> 0, "N_Eolica_Huasco_2"=> 0, "N_Eolica_Huasco_3"=> 0, "N_Solar_Huasco_2"=> 0, "N_Solar_Huasco_3" => 0,"N_Geotermia_DiegodeAlmagro" => 0,"N_Minihidro_Charrua" => 0,"N_Petroleo_DiegodeAlmagro"=> 1, "N_Petroleo_Huasco" => 1,"N_Petroleo_Quillota"=> 1, "N_Petroleo_RM"=> 1, "N_Petroleo_Coronel"=> 1, "N_Petroleo_PtoMontt"=> 1 )
# Datos de centrales nuevas
centrales_nuevas = ["N_Carbon_DiegodeAlmagro" "N_Carbon_Huasco" "N_Carbon_Quillota" "N_Carbon_RM" "N_Carbon_Coronel" "N_Carbon_PtoMontt" "N_GNL_Quillota" "N_Hidro_Charrua" "N_Eolica_Huasco_2" "N_Eolica_Huasco_3" "N_Solar_Huasco_2" "N_Solar_Huasco_3" "N_Geotermia_DiegodeAlmagro" "N_Minihidro_Charrua" "N_Petroleo_DiegodeAlmagro" "N_Petroleo_Huasco" "N_Petroleo_Quillota" "N_Petroleo_RM" "N_Petroleo_Coronel" "N_Petroleo_PtoMontt"]
Disponibilidad_Nueva = [0.88, 0.88, 0.88, 0.88, 0.88, 0.88, 0.93, 0.60, 0.35, 0.30, 0.35, 0.30, 0.80, 0.60, 0.80, 0.80, 0.80, 0.80, 0.80, 0.80]
Eficienica_Planta_nueva =[0.38,0.38, 0.38,0.38,0.38,0.38,0.45,1,1,1,1,1,1,1,0.30,0.30,0.30,0.30,0.30,0.30]
Vida_util_nuevas = [30,30,30,30,30,30,25,40, 20,20,20,20,20,40,20,20,20,20,20,20]
Precio_CV_Nuevos = [24.5,24.5,24.5,24.5,24.5,24.5,64.1,0,8,8,10,10,20,0,159.9,159.9,159.9,159.9,159.9,159.9]
Precio_kwneto = [2300,2300,2300, 2300, 2300,2300,1000,3000,1800,1800, 1500,1500,4000,3000,700, 700,700,700,700,700]
Precio_lineas = [10, 5, 0.3, 0.3, 3,5,0.3,10,5,5,5,5,20,20,10,5,0.3,0.3,3,5]
Maxima_Capacidad = [50000, 50000, 50000, 50000, 50000, 50000, 50000, 1500, 500, 50000, 500, 50000, 200, 500, 50000, 50000, 50000, 50000, 50000, 50000]

factor_planta_nuevas = Dict() #Factor de planta nuevas
eficiencia_planta_nuevas = Dict() #Eficiencia de las plantas nuevas
vidautil_nuevas = Dict() #Vida util centrales nuevas
cv_nuevas = Dict() #Costos variables nuevas
c_kwneto_nuevas = Dict() #Costos KW neto nuevas
cl_nuevas = Dict() #Costos lineas nuevas
restriccion_maxima_instalacion = Dict() #Costos lineas nuevas

for i in range(1,20) 
    factor_planta_nuevas[centrales_nuevas[i]] = Disponibilidad_Nueva[i]
    eficiencia_planta_nuevas[centrales_nuevas[i]] = Eficienica_Planta_nueva[i]
    vidautil_nuevas[centrales_nuevas[i]] = Vida_util_nuevas[i]
    cv_nuevas[centrales_nuevas[i]] = Precio_CV_Nuevos[i]
    c_kwneto_nuevas[centrales_nuevas[i]] = Precio_kwneto[i]
    cl_nuevas[centrales_nuevas[i]] = Precio_lineas[i]
    restriccion_maxima_instalacion[centrales_nuevas[i]] = Maxima_Capacidad[i]
end

tasa_dcto = 0.1
# Combinaciones para los abatidores de las centrales

abatidor_central = Dict();
abatidor_central[64] = Dict("abatidor_central"=>[], "anualidad"=>0, "costo_variable"=>0, "MP"=> 0, "NOx"=> 0, "SOx"=> 0,  "CO2" => 0.0);
abatidor_central[1] = Dict("NOx" => 0, "MP" => 0.9, "abatidor_central" => ["MP_1"], "anualidad" => 12.3, "costo_variable" => 1.5, "SOx" => 0, "CO2" => 0.0);
abatidor_central[2] = Dict("NOx" => 0, "MP" => 0.98, "abatidor_central" => ["MP_2"], "anualidad" => 16.77, "costo_variable" => 2.0, "SOx" => 0, "CO2" => 0.0);
abatidor_central[3] = Dict("NOx" => 0, "MP" => 0.99, "abatidor_central" => ["MP_3"], "anualidad" => 29.06, "costo_variable" => 2.0, "SOx" => 0, "CO2" => 0.0);
abatidor_central[4] = Dict("NOx" => 0, "MP" => 0, "abatidor_central" => ["SOx_1"], "anualidad" => 22.36, "costo_variable" => 1.5, "SOx" => 0.6, "CO2" => 0.0);
abatidor_central[5] = Dict("NOx" => 0, "MP" => 0, "abatidor_central" => ["SOx_2"], "anualidad" => 27.94, "costo_variable" => 2.0, "SOx" => 0.9, "CO2" => 0.0);
abatidor_central[6] = Dict("NOx" => 0, "MP" => 0, "abatidor_central" => ["SOx_3"], "anualidad" => 33.53, "costo_variable" => 2.0, "SOx" => 0.95, "CO2" => 0.0);
abatidor_central[7] = Dict("NOx" => 0.7, "MP" => 0, "abatidor_central" => ["NOx_1"], "anualidad" => 4.36, "costo_variable" => 1.5, "SOx" => 0, "CO2" => 0.0);
abatidor_central[8] = Dict("NOx" => 0.9, "MP" => 0, "abatidor_central" => ["NOx_2"], "anualidad" => 4.47, "costo_variable" => 2.0, "SOx" => 0, "CO2" => 0.0);
abatidor_central[9] = Dict("NOx" => 0.95, "MP" => 0, "abatidor_central" => ["NOx_3"], "anualidad" => 6.71, "costo_variable" => 2.0, "SOx" => 0, "CO2" => 0.0);
abatidor_central[10] = Dict("NOx" => 0, "MP" => 0.9, "abatidor_central" => ["MP_1", "SOx_1"], "anualidad" => 34.66, "costo_variable" => 3.0, "SOx" => 0.6, "CO2" => 0.0);
abatidor_central[11] = Dict("NOx" => 0, "MP" => 0.9, "abatidor_central" => ["MP_1", "SOx_2"], "anualidad" => 40.24, "costo_variable" => 3.5, "SOx" => 0.9, "CO2" => 0.0);
abatidor_central[12] = Dict("NOx" => 0, "MP" => 0.98, "abatidor_central" => ["MP_2", "SOx_1"], "anualidad" => 39.13, "costo_variable" => 3.5, "SOx" => 0.6, "CO2" => 0.0);
abatidor_central[13] = Dict("NOx" => 0, "MP" => 0.98, "abatidor_central" => ["MP_2", "SOx_2"], "anualidad" => 44.71, "costo_variable" => 4.0, "SOx" => 0.9, "CO2" => 0.0);
abatidor_central[14] = Dict("NOx" => 0, "MP" => 0.9, "abatidor_central" => ["MP_1", "SOx_3"], "anualidad" => 45.83, "costo_variable" => 3.5, "SOx" => 0.95, "CO2" => 0.0);
abatidor_central[15] = Dict("NOx" => 0, "MP" => 0.98, "abatidor_central" => ["MP_2", "SOx_3"], "anualidad" => 50.3, "costo_variable" => 4.0, "SOx" => 0.95, "CO2" => 0.0);
abatidor_central[16] = Dict("NOx" => 0, "MP" => 0.99, "abatidor_central" => ["MP_3", "SOx_1"], "anualidad" => 51.42, "costo_variable" => 3.5, "SOx" => 0.6, "CO2" => 0.0);
abatidor_central[17] = Dict("NOx" => 0, "MP" => 0.99, "abatidor_central" => ["MP_3", "SOx_2"], "anualidad" => 57.0, "costo_variable" => 4.0, "SOx" => 0.9, "CO2" => 0.0);
abatidor_central[18] = Dict("NOx" => 0, "MP" => 0.99, "abatidor_central" => ["MP_3", "SOx_3"], "anualidad" => 62.59, "costo_variable" => 4.0, "SOx" => 0.95, "CO2" => 0.0);
abatidor_central[19] = Dict("NOx" => 0.7, "MP" => 0.9, "abatidor_central" => ["MP_1", "NOx_1"], "anualidad" => 16.66, "costo_variable" => 3.0, "SOx" => 0, "CO2" => 0.0);
abatidor_central[20] = Dict("NOx" => 0.9, "MP" => 0.9, "abatidor_central" => ["MP_1", "NOx_2"], "anualidad" => 16.77, "costo_variable" => 3.5, "SOx" => 0, "CO2" => 0.0);
abatidor_central[21] = Dict("NOx" => 0.95, "MP" => 0.9, "abatidor_central" => ["MP_1", "NOx_3"], "anualidad" => 19.01, "costo_variable" => 3.5, "SOx" => 0, "CO2" => 0.0);
abatidor_central[22] = Dict("NOx" => 0.7, "MP" => 0.98, "abatidor_central" => ["MP_2", "NOx_1"], "anualidad" => 21.13, "costo_variable" => 3.5, "SOx" => 0, "CO2" => 0.0);
abatidor_central[23] = Dict("NOx" => 0.9, "MP" => 0.98, "abatidor_central" => ["MP_2", "NOx_2"], "anualidad" => 21.24, "costo_variable" => 4.0, "SOx" => 0, "CO2" => 0.0);
abatidor_central[24] = Dict("NOx" => 0.95, "MP" => 0.98, "abatidor_central" => ["MP_2", "NOx_3"], "anualidad" => 23.48, "costo_variable" => 4.0, "SOx" => 0, "CO2" => 0.0);
abatidor_central[25] = Dict("NOx" => 0.7, "MP" => 0.99, "abatidor_central" => ["MP_3", "NOx_1"], "anualidad" => 33.42, "costo_variable" => 3.5, "SOx" => 0, "CO2" => 0.0);
abatidor_central[26] = Dict("NOx" => 0.9, "MP" => 0.99, "abatidor_central" => ["MP_3", "NOx_2"], "anualidad" => 33.53, "costo_variable" => 4.0, "SOx" => 0, "CO2" => 0.0);
abatidor_central[27] = Dict("NOx" => 0.95, "MP" => 0.99, "abatidor_central" => ["MP_3", "NOx_3"], "anualidad" => 35.77, "costo_variable" => 4.0, "SOx" => 0, "CO2" => 0.0);


factores_ex = Dict();
factores_nu     = Dict();
normas_ex = Dict();
normas_nu = Dict();

factores_ex["Biomasa_Itahue"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)
factores_ex["Biomasa_Charrua"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)

factores_ex["Carbon_Huasco"] =Dict("NOx" => 16.5, "MP" => 44.61, "SOx" => 22.8, "CO2" => 2385.29, "Poder Calorifico" => 0.1323, "eficiencia" => 0.376, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_ex["Carbon_Quillota"] =Dict("NOx" => 16.5, "MP" => 44.61, "SOx" => 22.8, "CO2" => 2385.29, "Poder Calorifico" => 0.1323, "eficiencia" => 0.35, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)
factores_ex["Carbon_Coronel"] =Dict("NOx" => 16.5, "MP" => 44.61, "SOx" => 22.8, "CO2" => 2385.29, "Poder Calorifico" => 0.1323, "eficiencia" => 0.38, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)

factores_ex["GNL_Quillota"] =Dict("NOx" => 5.59, "MP" => 0.181, "SOx" => 0.014, "CO2" => 2856.0, "Poder Calorifico" => 0.06196, "eficiencia" => 0.454, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)

factores_ex["Petroleo_DiegodeAlmagro"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.28, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_ex["Petroleo_Cardones"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.335, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_ex["Petroleo_LosVilos"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.358, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)
factores_ex["Petroleo_Huasco"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.221, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_ex["Petroleo_PanAzucar"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.306, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_ex["Petroleo_Quillota"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.407, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)
factores_ex["Petroleo_Valparaiso"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.204, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)
factores_ex["Petroleo_RM"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.28, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)
factores_ex["Petroleo_Itahue"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.278, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_ex["Petroleo_Charrua"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.359, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_ex["Petroleo_Valdivia"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.296, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_ex["Petroleo_PtoMontt"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.361, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)

factores_ex["Hidro_Charrua"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)
factores_ex["Eolica_LosVilos"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)
factores_ex["Solar_Huasco"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)
factores_ex["Falla"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)

factores_nu["N_Carbon_DiegodeAlmagro"] =Dict("NOx" => 3.6, "MP" => 8.2, "SOx" => 18.6, "CO2" => 2164.71, "Poder Calorifico" => 0.1323, "eficiencia" => 0.38, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_nu["N_Carbon_Huasco"] =Dict("NOx" => 3.6, "MP" => 8.2, "SOx" => 18.6, "CO2" => 2164.71, "Poder Calorifico" => 0.1323, "eficiencia" => 0.38, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_nu["N_Carbon_Quillota"] =Dict("NOx" => 3.6, "MP" => 8.2, "SOx" => 18.6, "CO2" => 2164.71, "Poder Calorifico" => 0.1323, "eficiencia" => 0.38, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)
factores_nu["N_Carbon_RM"] =Dict("NOx" => 3.6, "MP" => 8.2, "SOx" => 18.6, "CO2" => 2164.71, "Poder Calorifico" => 0.1323, "eficiencia" => 0.38, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)
factores_nu["N_Carbon_Coronel"] =Dict("NOx" => 3.6, "MP" => 8.2, "SOx" => 18.6, "CO2" => 2164.71, "Poder Calorifico" => 0.1323, "eficiencia" => 0.38, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)
factores_nu["N_Carbon_PtoMontt"] =Dict("NOx" => 3.6, "MP" => 8.2, "SOx" => 18.6, "CO2" => 2164.71, "Poder Calorifico" => 0.1323, "eficiencia" => 0.38, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)

factores_nu["N_GNL_Quillota"] =Dict("NOx" => 5.59, "MP" => 0.181, "SOx" => 0.014, "CO2" => 2856.0, "Poder Calorifico" => 0.06196, "eficiencia" => 0.45, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)

factores_nu["N_Hidro_Charrua"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)
factores_nu["N_Eolica_Huasco_2"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)
factores_nu["N_Eolica_Huasco_3"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)
factores_nu["N_Solar_Huasco_2"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)
factores_nu["N_Solar_Huasco_3"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)
factores_nu["N_Geotermia_DiegodeAlmagro"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)
factores_nu["N_Minihidro_Charrua"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0, "CSMP" =>0,"CSSOx" =>0,"CSNOx" =>0,"CSCO2" =>0)

factores_nu["N_Petroleo_DiegodeAlmagro"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.3, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_nu["N_Petroleo_Huasco"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.3, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)
factores_nu["N_Petroleo_Quillota"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.3, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)
factores_nu["N_Petroleo_RM"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.3, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)
factores_nu["N_Petroleo_Coronel"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.3, "CSMP" =>3161.083,"CSSOx" =>1580.541,"CSNOx" =>2107.389,"CSCO2" =>50)
factores_nu["N_Petroleo_PtoMontt"] =Dict("NOx" => 1.42, "MP" => 0.28, "SOx" => 23.08, "CO2" => 3163.16, "Poder Calorifico" => 0.07968, "eficiencia" => 0.3, "CSMP" =>526.847,"CSSOx" =>210.73,"CSNOx" =>105.37,"CSCO2" =>50)

normas_ex["Biomasa_Itahue"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Biomasa_Charrua"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Carbon_Huasco"] =Dict("NOx" => 0.0, "MP" => 0.99, "SOx" => 0.95, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Carbon_Quillota"] =Dict("NOx" => 0.0, "MP" => 0.99, "SOx" => 0.95, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Carbon_Coronel"] =Dict("NOx" => 0.0, "MP" => 0.99, "SOx" => 0.95, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["GNL_Quillota"] =Dict("NOx" => 0.9, "MP" => 0.95, "SOx" => 0.0, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_DiegodeAlmagro"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_Cardones"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_LosVilos"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_Huasco"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_PanAzucar"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_Quillota"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_Valparaiso"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_RM"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_Itahue"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_Charrua"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_Valdivia"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Petroleo_PtoMontt"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Hidro_Charrua"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Eolica_LosVilos"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Solar_Huasco"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_ex["Falla"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Carbon_DiegodeAlmagro"] =Dict("NOx" => 0.0, "MP" => 0.99, "SOx" => 0.95, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Carbon_Huasco"] =Dict("NOx" => 0.0, "MP" => 0.99, "SOx" => 0.95, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Carbon_Quillota"] =Dict("NOx" => 0.0, "MP" => 0.99, "SOx" => 0.95, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Carbon_RM"] =Dict("NOx" => 0.0, "MP" => 0.99, "SOx" => 0.95, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Carbon_Coronel"] =Dict("NOx" => 0.0, "MP" => 0.99, "SOx" => 0.95, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Carbon_PtoMontt"] =Dict("NOx" => 0.0, "MP" => 0.99, "SOx" => 0.95,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_GNL_Quillota"] =Dict("NOx" => 0.9, "MP" => 0.95, "SOx" => 0.0, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Hidro_Charrua"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Eolica_Huasco_2"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Eolica_Huasco_3"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Solar_Huasco_2"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Solar_Huasco_3"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Geotermia_DiegodeAlmagro"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Minihidro_Charrua"] =Dict("NOx" => 0.0, "MP" => 0.0, "SOx" => 0.0, "CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Petroleo_DiegodeAlmagro"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Petroleo_Huasco"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Petroleo_Quillota"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Petroleo_RM"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Petroleo_Coronel"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0, "CO2" => 0.0,"Poder Calorifico" => 0, "eficiencia" => 0)
normas_nu["N_Petroleo_PtoMontt"] =Dict("NOx" => 0.0, "MP" => 0.95, "SOx" => 0.0,"CO2" => 0.0, "Poder Calorifico" => 0, "eficiencia" => 0)

function Anualidad(c)
    return 1000 * c_kwneto_nuevas[c] * tasa_dcto/(1-1/((1+tasa_dcto)^(vidautil_nuevas[c]))) 
end
function Anualidad_Abatidor(f,c)
    return 1000 * abatidor_central[f]["anualidad"]
end
function Costos_Lineas(c,b)
    return cl_nuevas[c]*du_blq[b]
end
function Costos_Variables_Existentes(c,b,f)
    return (cv[c] + abatidor_central[f]["costo_variable"])*du_blq[b]
end
function Costos_Variables_Nuevas(c,b,f)
    return (cv_nuevas[c]+ abatidor_central[f]["costo_variable"])*du_blq[b]
end

function EmisionesMarginalesNuevas(c,emision)
    return factores_nu[c]["Poder Calorifico"]*factores_nu[c][emision]/factores_nu[c]["eficiencia"]
end
function EmisionesMarginalesExistentes(c,emision)
    return factores_ex[c]["Poder Calorifico"]*factores_ex[c][emision]/factores_ex[c]["eficiencia"]
end
function DyA(b,f,emision)
    return du_blq[b]*(1-abatidor_central[f][emision])
end

emisiones = ["MP", "NOx", "SOx", "CO2"]
PoliticaCO2 = 0.75

function correr_modelo()

    model = Model()
    set_optimizer(model, GLPK.Optimizer)

    @variable(model, potencia_central[c in centrales_existentes, b in bloques, f in keys(abatidor_central)] >= 0) 
    @variable(model, potencia_central_nueva[c in centrales_nuevas, b in bloques, f in keys(abatidor_central)] >= 0) 
    @variable(model, potencia_instalada_existente[c in centrales_existentes, f in keys(abatidor_central)] >= 0) 
    @variable(model, potencia_instalada_nueva[c in centrales_nuevas, f in keys(abatidor_central)] >= 0) 

    @objective(model, Min, 
    sum(potencia_central[c,b,f]*Costos_Variables_Existentes(c,b,f) for c in centrales_existentes, b in bloques, f in keys(abatidor_central)) 
    + sum(potencia_central_nueva[c,b,f]*(Costos_Variables_Nuevas(c,b,f) + Costos_Lineas(c,b)) for c in centrales_nuevas, b in bloques, f in keys(abatidor_central))
    + sum(potencia_instalada_nueva[c,f] *(Anualidad(c) + Anualidad_Abatidor(f,c)) for c in centrales_nuevas, f in keys(abatidor_central)) 
    + sum(potencia_instalada_existente[c,f] * Anualidad_Abatidor(f,c) for c in centrales_existentes, f in keys(abatidor_central))
    )

    @constraint(model, demanda[b in bloques], sum(potencia_central[c,b,f] for c in centrales_existentes, f in keys(abatidor_central)) + sum(potencia_central_nueva[c,b,f] for c in centrales_nuevas, f in keys(abatidor_central))>=de_blq[b])
    @constraint(model, geneneracion_maxima_existente[c in centrales_existentes,b in bloques, f in keys(abatidor_central)], potencia_central[c,b,f] <= potencia_instalada_existente[c,f]*factor_planta[c])
    @constraint(model, geneneracion_maxima_nueva[c in centrales_nuevas,b in bloques, f in keys(abatidor_central)], potencia_central_nueva[c,b,f] <= potencia_instalada_nueva[c,f]*factor_planta_nuevas[c])
    @constraint(model, capacidad_maxima[c in centrales_nuevas], sum( potencia_instalada_nueva[c,f] for f in keys(abatidor_central))<= restriccion_maxima_instalacion[c])
    @constraint(model, Potencia_inst_existente[c in centrales_existentes], sum(potencia_instalada_existente[c,f] for f in keys(abatidor_central)) == pot_in[c])

    @constraint(model, restriccionMP_Existentes2[c in centrales_existentes, f in keys(abatidor_central)], contaminante[c]*potencia_instalada_existente[c,f]*factores_ex[c]["MP"]*(1-abatidor_central[f]["MP"]) <= contaminante[c]*potencia_instalada_existente[c,f]*factores_ex[c]["MP"]*(1-normas_ex[c]["MP"]))
    @constraint(model, restriccionNOx_Existentes2[c in centrales_existentes, f in keys(abatidor_central)],  contaminante[c]*potencia_instalada_existente[c,f]*factores_ex[c]["NOx"]*(1-abatidor_central[f]["NOx"]) <= contaminante[c]*potencia_instalada_existente[c,f]*factores_ex[c]["NOx"]*(1-normas_ex[c]["NOx"]))
    @constraint(model, restriccionSOx_Existentes2[c in centrales_existentes, f in keys(abatidor_central)],  contaminante[c]*potencia_instalada_existente[c,f]*factores_ex[c]["SOx"]*(1-abatidor_central[f]["SOx"]) <= contaminante[c]*potencia_instalada_existente[c,f]*factores_ex[c]["SOx"]*(1-normas_ex[c]["SOx"]))
    @constraint(model, restriccionMP_Nuevas2[c in centrales_nuevas, f in keys(abatidor_central)],  contaminante[c]*potencia_instalada_nueva[c,f]*factores_nu[c]["MP"]*(1-abatidor_central[f]["MP"]) <= contaminante[c]*potencia_instalada_nueva[c,f]*factores_nu[c]["MP"]*(1-normas_nu[c]["MP"]))
    @constraint(model, restriccionNOx_Nuevas2[c in centrales_nuevas, f in keys(abatidor_central)],  contaminante[c]*potencia_instalada_nueva[c,f]*factores_nu[c]["NOx"]*(1-abatidor_central[f]["NOx"]) <= contaminante[c]*potencia_instalada_nueva[c,f]*factores_nu[c]["NOx"]*(1-normas_nu[c]["NOx"]))
    @constraint(model, restriccionSOx_Nuevas2[c in centrales_nuevas, f in keys(abatidor_central)],  contaminante[c]*potencia_instalada_nueva[c,f]*factores_nu[c]["SOx"]*(1-abatidor_central[f]["SOx"]) <= contaminante[c]*potencia_instalada_nueva[c,f]*factores_nu[c]["SOx"]*(1-normas_nu[c]["SOx"]))

    @constraint(model, EmisionesPolitica,  sum(factores_ex[c]["Poder Calorifico"] != 0 ?  EmisionesMarginalesExistentes(c,"CO2")*sum(potencia_central[c,b,f]*DyA(b,f,"CO2") for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_existentes) + sum(factores_nu[c]["Poder Calorifico"] != 0 ? EmisionesMarginalesNuevas(c,"CO2")*sum(potencia_central_nueva[c,b,f]*DyA(b,f,"CO2") for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_nuevas) <= 20459754* PoliticaCO2 + 1)

    JuMP.optimize!(model)

    return [model,potencia_central,potencia_central_nueva,potencia_instalada_existente,potencia_instalada_nueva]
end

resultado = correr_modelo()
model = resultado[1];
potencia_central = resultado[2];
potencia_central_nueva = resultado[3];
potencia_instalada_existente = resultado[4];
potencia_instalada_nueva = resultado[5];

println("Costo total: ", JuMP.objective_value(model))

global sumaTotal = 0;
for e in emisiones
    global suma = 0;
    suma = sum(factores_ex[c]["Poder Calorifico"] != 0 ?  EmisionesMarginalesExistentes(c,e)*sum(JuMP.value(potencia_central[c,b,f]*DyA(b,f,e)) for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_existentes) + sum(factores_nu[c]["Poder Calorifico"] != 0 ? EmisionesMarginalesNuevas(c,e)*sum(JuMP.value(potencia_central_nueva[c,b,f]*DyA(b,f,e)) for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_nuevas)
    println("Total ",e,": ", suma)
    global sumaTotal = sumaTotal + suma
end

global suma = 0;
suma = sum(factores_ex[c]["Poder Calorifico"] != 0 ?  factores_ex[c]["CSMP"]*EmisionesMarginalesExistentes(c,"MP")*sum(JuMP.value(potencia_central[c,b,f]*DyA(b,f,"MP")) for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_existentes) + sum(factores_nu[c]["Poder Calorifico"] != 0 ? factores_nu[c]["CSMP"]*EmisionesMarginalesNuevas(c,"MP")*sum(JuMP.value(potencia_central_nueva[c,b,f]*DyA(b,f,"MP")) for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_nuevas)
println("Total COSTO SOCIAL MP: ", suma)

global suma = 0;
suma = sum(factores_ex[c]["Poder Calorifico"] != 0 ?  factores_ex[c]["CSNOx"]*EmisionesMarginalesExistentes(c,"NOx")*sum(JuMP.value(potencia_central[c,b,f]*DyA(b,f,"NOx")) for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_existentes) + sum(factores_nu[c]["Poder Calorifico"] != 0 ? factores_nu[c]["CSNOx"]*EmisionesMarginalesNuevas(c,"NOx")*sum(JuMP.value(potencia_central_nueva[c,b,f]*DyA(b,f,"NOx")) for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_nuevas)
println("Total COSTO SOCIAL NOx: ", suma)

global suma = 0;
suma = sum(factores_ex[c]["Poder Calorifico"] != 0 ?  factores_ex[c]["CSSOx"]*EmisionesMarginalesExistentes(c,"SOx")*sum(JuMP.value(potencia_central[c,b,f]*DyA(b,f,"SOx")) for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_existentes) + sum(factores_nu[c]["Poder Calorifico"] != 0 ? factores_nu[c]["CSSOx"]*EmisionesMarginalesNuevas(c,"SOx")*sum(JuMP.value(potencia_central_nueva[c,b,f]*DyA(b,f,"SOx")) for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_nuevas)
println("Total COSTO SOCIAL SOx: ", suma)

global suma = 0;
suma = sum(factores_ex[c]["Poder Calorifico"] != 0 ?  factores_ex[c]["CSCO2"]*EmisionesMarginalesExistentes(c,"CO2")*sum(JuMP.value(potencia_central[c,b,f]*DyA(b,f,"CO2")) for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_existentes) + sum(factores_nu[c]["Poder Calorifico"] != 0 ? factores_nu[c]["CSCO2"]*EmisionesMarginalesNuevas(c,"CO2")*sum(JuMP.value(potencia_central_nueva[c,b,f]*DyA(b,f,"CO2")) for f in keys(abatidor_central) for b in bloques)/1000 : 0 for c in centrales_nuevas)
println("Total COSTO SOCIAL CO2: ", suma)