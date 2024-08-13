SET search_path TO sube_agreg;

----------------- 1 -------------------------

-- Veo algunos campos
select * from viajes_transp limit 5;
-- Cuento los valores distintos de cada variable categórica
select count(*) from viajes_transp;
select count(distinct nombre_empresa) from viajes_transp;
select count(distinct linea) from viajes_transp;
select count(distinct tipo_transporte) from viajes_transp;
select count(distinct tipo_jurisdiccion) from viajes_transp;
select count(distinct provincia) from viajes_transp;
select count(distinct municipio) from viajes_transp;

-- Cuento cuántas veces aparece cada valor en algunas variables categóricas
select AMBA, count(AMBA) from viajes_transp group by rollup(AMBA);
select tipo_jurisdiccion, count(tipo_jurisdiccion) from viajes_transp group by rollup(tipo_jurisdiccion);
select provincia, count(provincia) from viajes_transp group by rollup(provincia);


-- Cuento valores únicos

select count(municipio)
from (
	select municipio 
	from viajes_transp
	group by municipio
	having count(municipio) = 1);
	
select count(provincia)
from (
	select provincia 
	from viajes_transp
	group by provincia
	having count(provincia) = 1);
	
select count(nombre_empresa)
from (
	select nombre_empresa 
	from viajes_transp
	group by nombre_empresa
	having count(nombre_empresa) = 1);
	
select count(tipo_transporte)
from (
	select tipo_transporte 
	from viajes_transp
	group by tipo_transporte
	having count(tipo_transporte) = 1);
	
select count(linea)
from (
	select linea 
	from viajes_transp
	group by linea
	having count(linea) = 1);
	


----------------- 2 -------------------------

-- Analizo datos faltantes para cada variable
select 	sum(case when dia is null then 1 else 0 end) dias_null,
		sum(case when coalesce(nombre_empresa,'') = '' then 1 else 0 end) empresas_null,
		sum(case when coalesce(linea,'') = '' then 1 else 0 end) lineas_null,
		sum(case when coalesce(amba,'') = '' then 1 else 0 end) amba_null,
		sum(case when coalesce(tipo_transporte,'') = '' then 1 else 0 end) transporte_null,
		sum(case when coalesce(tipo_jurisdiccion,'') = '' then 1 else 0 end) jurisdiccion_null,
		sum(case when coalesce(provincia,'') = '' then 1 else 0 end) provincia_null,
		sum(case when coalesce(municipio,'') = '' then 1 else 0 end) municipio_null,
		sum(case when cant_viajes is null then 1 else 0 end) viajes_null
from viajes_transp;

----------------- 3 -------------------------

-- a)
CREATE VIEW viajes_transp_expand AS
select *, TO_CHAR(dia, 'day') dia_semana, EXTRACT('YEAR' FROM dia) anio
from viajes_transp;

DROP VIEW viajes_transp_expand;

-- b)

select anio, tipo_transporte, tipo_jurisdiccion, amba, sum(cant_viajes) cant_viajes_totales, count(distinct linea) cant_lineas
from viajes_transp_expand
--group by rollup(anio, tipo_transporte,  tipo_jurisdiccion, amba);
group by cube(anio, tipo_transporte,  tipo_jurisdiccion, amba);

-- c)

-- i
select sum(cant_viajes), 
		avg(cant_viajes),
		STDDEV(cant_viajes),
		min(cant_viajes),
		max(cant_viajes),
		PERCENTILE_CONT(0.5) within group (order by cant_viajes) mediana,
		PERCENTILE_CONT(0.25) within group (order by cant_viajes) Q1,
		PERCENTILE_CONT(0.75) within group (order by cant_viajes) Q3,
		(4 * PERCENTILE_CONT(0.75) within group (order by cant_viajes)) -
			( 3 * PERCENTILE_CONT(0.25) within group (order by cant_viajes)) Q3_mas_3IQR,
		(4 * PERCENTILE_CONT(0.25) within group (order by cant_viajes)) -
			( 3 * PERCENTILE_CONT(0.75) within group (order by cant_viajes)) Q1_menos_3IQR
from viajes_transp v;

-- ii
select anio,
		amba,
		sum(cant_viajes), 
		avg(cant_viajes),
		STDDEV(cant_viajes),
		min(cant_viajes),
		max(cant_viajes),
		PERCENTILE_CONT(0.5) within group (order by cant_viajes) mediana,
		PERCENTILE_CONT(0.25) within group (order by cant_viajes) Q1,
		PERCENTILE_CONT(0.75) within group (order by cant_viajes) Q3,
		(4 * PERCENTILE_CONT(0.75) within group (order by cant_viajes)) -
			( 3 * PERCENTILE_CONT(0.25) within group (order by cant_viajes)) Q3_mas_3IQR,
		(4 * PERCENTILE_CONT(0.25) within group (order by cant_viajes)) -
			( 3 * PERCENTILE_CONT(0.75) within group (order by cant_viajes)) Q1_menos_3IQR
from viajes_transp_expand v
group by anio, amba;

-- iii
select anio,
		amba,
		tipo_jurisdiccion,
		tipo_transporte,
		sum(cant_viajes), 
		avg(cant_viajes),
		STDDEV(cant_viajes),
		min(cant_viajes),
		max(cant_viajes),
		PERCENTILE_CONT(0.5) within group (order by cant_viajes) mediana,
		PERCENTILE_CONT(0.25) within group (order by cant_viajes) Q1,
		PERCENTILE_CONT(0.75) within group (order by cant_viajes) Q3,
		(4 * PERCENTILE_CONT(0.75) within group (order by cant_viajes)) -
			( 3 * PERCENTILE_CONT(0.25) within group (order by cant_viajes)) Q3_mas_3IQR,
		(4 * PERCENTILE_CONT(0.25) within group (order by cant_viajes)) -
			( 3 * PERCENTILE_CONT(0.75) within group (order by cant_viajes)) Q1_menos_3IQR
from viajes_transp_expand v
group by anio, amba, tipo_jurisdiccion, tipo_transporte;


------------------- 6 -------------------------

-- a)

-- Obtener las líneas con la máxima cantidad de viajes de cada jurisdicción y 
-- tipo de transporte (conjuntamente) en el año 2022. La salida debe tener los
-- campos tipo_jurisdiccion, provincia, municipio, tipo_transporte, línea, 
-- cantidad de viajes de la línea, y cantidad de días de actividad de la línea. 
-- Debe estar ordenada según la cantidad de viajes de la línea de mayor a menor. 
-- No deben aparecer líneas que no cumplan esta condición. Resolver con una única consulta.

select tipo_jurisdiccion, provincia, municipio, tipo_transporte, 
		linea, cant_viajes_acum, cantidad_dias_actividad
from
	(select t.tipo_jurisdiccion, t.provincia, t.municipio, t.tipo_transporte, t.linea,
			sum(t.cant_viajes) cant_viajes_acum, 
			count(distinct t.dia) as cantidad_dias_actividad,
			rank() over (partition by t.tipo_jurisdiccion, t.provincia, t.municipio, t.tipo_transporte
						 order by sum(t.cant_viajes) desc) as rank
	from viajes_transp_expand t
	where anio = 2022
	group by tipo_jurisdiccion, provincia, municipio, tipo_transporte, linea
	 
	)
where rank = 1
order by cant_viajes_acum desc

-- b)

-- Considerando los viajes totales mensuales de cada línea de colectivos de AMBA, 
-- devolver para cada línea el mes de mayor variación intermensual porcentual. 
-- Se debe devolver el nombre de la línea, el tipo de jurisdicción, la provincia, 
-- el municipio, el mes y cantidad de viajes del mes previo de la variación, el mes 
-- y la cantidad de viajes del mes actual de la variación, y el valor de la variación 
-- porcentual intermensual entre esos dos meses. Resolver con una única consulta.


with viajes_por_mes as (
	select t.tipo_jurisdiccion, t.provincia, t.municipio, t.linea, 
			EXTRACT('MONTH' FROM dia) mes_actual, sum(t.cant_viajes) viajes_mes_actual,
			lag(EXTRACT('MONTH' FROM dia)) over (partition by tipo_jurisdiccion, provincia, municipio, linea) mes_previo,
			lag(sum(t.cant_viajes)) over (partition by tipo_jurisdiccion, provincia, municipio, linea) viajes_mes_previo
	from viajes_transp_expand t
	where AMBA = 'SI' and tipo_transporte = 'COLECTIVO' and anio = 2022 --anio > 2020 
	group by tipo_jurisdiccion, provincia, municipio, linea, EXTRACT('MONTH' FROM dia)
	)
select  linea, tipo_jurisdiccion, provincia, municipio, 
		mes_previo, viajes_mes_previo,
		mes_actual, viajes_mes_actual,
		variacion_mensual_viajes
from (		
	select linea, tipo_jurisdiccion, provincia, municipio, 
			mes_previo, viajes_mes_previo,
			mes_actual, viajes_mes_actual, 
			(viajes_mes_actual::numeric / coalesce(viajes_mes_previo, viajes_mes_actual)::numeric - 1) variacion_mensual_viajes,
			rank() over (partition by tipo_jurisdiccion, provincia, municipio, linea
							 order by (viajes_mes_actual::numeric / coalesce(viajes_mes_previo, viajes_mes_actual)::numeric - 1) desc) as rank
	from viajes_por_mes
	)
where rank = 1;



