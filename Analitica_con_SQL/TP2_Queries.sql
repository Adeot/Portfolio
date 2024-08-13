SET SEARCH_PATH TO sube_det, public;


-- Veo algunas filas de cada tabla
select * from datos_eco_gral_puey limit 10;
select * from puntos_interes_gral_puey;

select count(distinct linea) from datos_eco_gral_puey;
select avg(cant_trx), min(cant_trx), max(cant_trx) from datos_eco_gral_puey;

--------------- 2 -----------------

CREATE VIEW datos_Eco_Gral_Puey_expand AS
SELECT d.*,
       ST_POINT((d.lat_lon->>'lon')::numeric, (d.lat_lon->>'lat')::numeric, 4326) AS ubicacion,
       pi.lugar AS pi_nombre,  -- pi = punto de interés
       pi.geom AS pi_ubicacion,
	   st_geohash(pi.geom, 6) pi_gh6,
	   ST_SETSRID(ST_pointFromGeoHash (st_geohash(pi.geom, 6)), 4326)  pi_centroide_gh,
	   ST_SETSRID(ST_geomFromGeoHash (st_geohash(pi.geom, 6)), 4326) pi_zona_gh
FROM datos_Eco_Gral_Puey d
LEFT JOIN puntos_interes_gral_puey pi 
ON ST_DWithin(ST_POINT((d.lat_lon->>'lon')::numeric, (d.lat_lon->>'lat')::numeric, 4326)::geography, pi.geom::geography, 500);

--------------- 3 -----------------

-- Comparo visualmente los puntos de transacción con la región del municipio provista por Google Maps.
-- Concluyo que están todos en el municipio.
-- Además observo que solo 3 puntos de interés están cerca de los de transacciones.

SELECT ST_POINT((d.lat_lon->>'lon')::numeric, (d.lat_lon->>'lat')::numeric, 4326) AS ubicacion
FROM datos_Eco_Gral_Puey d

select ubicacion, pi_ubicacion 
from datos_Eco_Gral_Puey_expand;

--------------- 4 -----------------

select * from puntos_interes_gral_puey;

INSERT INTO sube_det.puntos_interes_gral_puey 
SELECT 'MUSEO MUNICIPAL DE CIENCIAS NATURALES' lugar, ST_POINT(-57.546379, -37.990931, 4326 ) geom
UNION ALL
SELECT 'MUSEO DE LA FUERZA DE SUBMARINOS' lugar , ST_POINT(-57.528588, -38.033563, 4326) geom
UNION ALL
SELECT 'MONUMENTO AL GAUCHO' lugar, ST_POINT(-57.597502, -37.999317, 4326) geom

-- Me fijo que los puntos de interés estén separados a más de 1200m
-- Devuelve los pares de puntos que lo estén.
-- Da vacío.
select pi1.lugar lugar_cercano_1, pi2.lugar lugar_cercano_2 
from puntos_interes_gral_puey pi1
join puntos_interes_gral_puey pi2
on ST_DWithin(pi1.geom::geography, pi2.geom::geography, 1200)
	and pi1.lugar <> pi2.lugar;
	
	
--------------- 5 A -----------------

-- El día es el mismo para todos los registros, por lo 
-- que no lo tomo en cuenta.

-- i)

-- Horas de mayor demanda (asumo que elijo las 3 primeras)
select hora, sum(cant_trx) cant_trx_total
from datos_eco_gral_puey
where hora >= 6 and hora <= 20
group by hora
order by cant_trx_total desc
limit 3;

-- Las 3 horas de menor demanda
select hora, sum(cant_trx) cant_trx_total
from datos_eco_gral_puey
where hora >= 6 and hora <= 20
group by hora
order by cant_trx_total asc
limit 3;

-- ii)

-- Horas de mayor demanda (asumo que elijo las 3 primeras).

-- Primero me quedo con los registros únicos de los primeros 6 
-- campos de la tabla extendida tales que su punto de interés
-- esté en lista que nos interesa, ya que se podría contar un valor 
-- más de una vez en la agregación. En realidad esto no haría falta
-- para estos datos en particular porque dichos puntos ya están
-- a más de 1200m de distancia entre sí, por lo que ningún punto
-- del trayecto va a tener dos puntos de interés asociados. Lo 
-- mantengo por consistencia.

with datos_cercanos_a_pto_interes as (
	select distinct hora, empresa, linea, lat_lon, tipo_tarifa, cant_trx
	from datos_eco_gral_puey_expand
	where hora >= 6 and hora <= 20 and
		(pi_nombre = 'CASINO CENTRAL' or pi_nombre = 'FCEYN - UNMDP' or pi_nombre = 'TERMINAL DE OMNIBUS'
		or pi_nombre = 'MUSEO MUNICIPAL DE CIENCIAS NATURALES' or pi_nombre = 'MUSEO DE LA FUERZA DE SUBMARINOS' or pi_nombre = 'MONUMENTO AL GAUCHO')
)
select hora, sum(cant_trx) cant_trx_total
from datos_cercanos_a_pto_interes
group by hora
order by cant_trx_total desc
limit 3;

-- Las 3 horas de menor demanda

-- Mismo código pero con un asc.

with datos_cercanos_a_pto_interes as (
	select distinct hora, empresa, linea, lat_lon, tipo_tarifa, cant_trx
	from datos_eco_gral_puey_expand
	where hora >= 6 and hora <= 20 and
		(pi_nombre = 'CASINO CENTRAL' or pi_nombre = 'FCEYN - UNMDP' or pi_nombre = 'TERMINAL DE OMNIBUS'
		or pi_nombre = 'MUSEO MUNICIPAL DE CIENCIAS NATURALES' or pi_nombre = 'MUSEO DE LA FUERZA DE SUBMARINOS' or pi_nombre = 'MONUMENTO AL GAUCHO')
)
select hora, sum(cant_trx) cant_trx_total
from datos_cercanos_a_pto_interes
group by hora
order by hora
--order by cant_trx_total asc
limit 3;

-- iii)

-- Veo el número de viajes por hora usando el graph visualizer
select hora, sum(cant_trx) from datos_eco_gral_puey group by hora order by hora;

--------------- 5 B -----------------

-- No hay puntos de trayectoria con dos puntos de interés
-- así que no hago un filtro.

-- i)

select st_geohash(ubicacion, 6) zona_gh6
from datos_eco_gral_puey_expand
group by zona_gh6
order by sum(cant_trx) desc
limit 5;

-- ii)

with datos_eco_gral_puey_expand_gh as (
	select st_geohash(ubicacion, 6) zona_gh6, tipo_tarifa, sum(cant_trx) cant_trx_total
	from datos_eco_gral_puey_expand
	group by tipo_tarifa, zona_gh6 
)
select tipo_tarifa, zona_gh6
from (
	select d.tipo_tarifa, d.zona_gh6 ,
		rank() over (partition by d.tipo_tarifa order by d.cant_trx_total desc) as rank
	from datos_eco_gral_puey_expand_gh d
	)
where rank <= 5;

-- iii)

with datos_eco_gral_puey_expand_gh as (
	select st_geohash(ubicacion, 6) zona_gh6, hora, sum(cant_trx) cant_trx_total
	from datos_eco_gral_puey_expand
	where hora in (5, 12, 17)
	group by hora, zona_gh6 
)
select hora, zona_gh6
from (
	select d.hora, d.zona_gh6 ,
		rank() over (partition by d.hora order by d.cant_trx_total desc) as rank
	from datos_eco_gral_puey_expand_gh d
	)
where rank <= 5;

-- iv)

select st_geohash(ubicacion, 6) zona_gh6, count(distinct linea) cant_lineas_dif
from datos_eco_gral_puey_expand
group by zona_gh6
order by cant_lineas_dif desc
limit 5;

-- v)

select st_geohash(ubicacion, 6) zona_gh6
from datos_eco_gral_puey_expand
group by zona_gh6
having count(distinct linea) = 1;

-- vi)

-- Grafico los geohashes del punto i
select ST_GeomFromGeoHash(st_geohash(ubicacion, 6), 6)::geography zona_gh6
from datos_eco_gral_puey_expand
group by zona_gh6
order by sum(cant_trx) desc
limit 5;

-- Grafico los geohashes del punto v
select ST_GeomFromGeoHash(st_geohash(ubicacion, 6), 6)::geography zona_gh6
from datos_eco_gral_puey_expand
group by zona_gh6
having count(distinct linea) = 1;

-- vii)

-- Geohashes con linea max
select distinct st_geohash(ubicacion, 6)
from datos_eco_gral_puey_expand
where linea = (
	select linea
	from datos_eco_gral_puey_expand
	group by linea
	order by sum(cant_trx) desc
	limit 1
);

-- Geohashes con linea min
select distinct st_geohash(ubicacion, 6)
from datos_eco_gral_puey_expand
where linea = (
	select linea
	from datos_eco_gral_puey_expand
	group by linea
	order by sum(cant_trx) asc
	limit 1
);

-- Geohash-hora de linea max con mayor ascensos
with geogash_hora_ascensos_linea_max as (
	select st_geohash(ubicacion, 6) gh, hora, sum(cant_trx) ascensos
	from datos_eco_gral_puey_expand
	where linea = (
		select linea
		from datos_eco_gral_puey_expand
		group by linea
		order by sum(cant_trx) desc
		limit 1)
	group by st_geohash(ubicacion, 6), hora -- linea no porque está fijada
	order by ascensos desc
	limit 1
)
select gh, hora
from geogash_hora_ascensos_linea_max

-- Geohash-hora de linea min con mayor ascensos (solo cambia desc por asc en la subconsulta)
with geogash_hora_ascensos_linea_min as (
	select st_geohash(ubicacion, 6) gh, hora, sum(cant_trx) ascensos
	from datos_eco_gral_puey_expand
	where linea = (
		select linea
		from datos_eco_gral_puey_expand
		group by linea
		order by sum(cant_trx) asc
		limit 1)
	group by st_geohash(ubicacion, 6), hora -- linea no porque está fijada
	order by ascensos desc
	limit 1
)
select gh, hora
from geogash_hora_ascensos_linea_min

-- viii)

-- linea que pasa por más puntos de interés

select linea
from datos_eco_gral_puey_expand
where pi_nombre not in ('MUSEO MUNICIPAL DE CIENCIAS NATURALES', 'MUSEO DE LA FUERZA DE SUBMARINOS', 'MONUMENTO AL GAUCHO')
		and pi_nombre is not null
group by linea
order by count(distinct pi_nombre) desc
limit 1

-- Puntos de interés (sin contar los agregados) donde pasa la linea con más puntos de interés 

select distinct pi_nombre
from datos_eco_gral_puey_expand
where linea = (
	select d.linea
	from datos_eco_gral_puey_expand d
	where d.pi_nombre not in ('MUSEO MUNICIPAL DE CIENCIAS NATURALES', 'MUSEO DE LA FUERZA DE SUBMARINOS', 'MONUMENTO AL GAUCHO')
			and d.pi_nombre is not null
	group by d.linea
	order by count(distinct d.pi_nombre) desc
	limit 1
	)
	and pi_nombre is not null

