create table test_artsoft_new()

ALTER TABLE test_artsoft_new
ADD ym_pv_watchID integer,
ADD ym_pv_date date,
ADD ym_pv_dateTime timestamp,
ADD ym_pv_URL varchar(255),
ADD ym_pv_referer varchar(255),
ADD ym_pv_browser varchar(255),
ADD ym_pv_deviceCategory integer,
ADD ym_pv_mobilePhone varchar(255),
ADD ym_pv_operatingSystemRoot varchar(255),
ADD ym_pv_regionCity varchar(255),
ADD ym_pv_regionCountry varchar(255),
ADD ym_pv_lastTrafficSource varchar(255),
ADD ym_pv_notBounce integer,
ADD ym_pv_lastSocialNetwork varchar(255),
ADD ym_pv_clientID integer,
ADD ym_pv_networkType varchar(255),
ADD mark varchar(255),
ADD model varchar(255),
ADD car_id varchar(255);

ALTER TABLE test_artsoft_new ALTER COLUMN ym_pv_watchID TYPE varchar(255);
ALTER TABLE test_artsoft_new ALTER COLUMN ym_pv_clientID TYPE varchar(255);
ALTER TABLE test_artsoft_new ALTER COLUMN ym_pv_URL TYPE text;
ALTER TABLE test_artsoft_new ALTER COLUMN ym_pv_referer TYPE text;

/*копируем файл toretto_car_new.csv  в таблицу test_artsoft_new*/

/*1*/
/*Выведите 10 самых популярных брендов и моделей, имеющие больше всего
просмотров.*/
select mark, model, count(model) as cnt from 
(select * from test_artsoft_new where not mark is null) t
group by mark,model
order by cnt DESC
limit 10



/*...........2..........*/
/*Посчитайте среднюю длину сессии*/
with t as(
SELECT
ym_pv_clientID,
ym_pv_dateTime,
ym_pv_notBounce,
ym_pv_deviceCategory,
CASE
WHEN ym_pv_dateTime - LAG(ym_pv_dateTime) OVER (PARTITION BY ym_pv_clientID ORDER BY ym_pv_dateTime) >= INTERVAL '30' MINUTE
OR LAG(ym_pv_dateTime) OVER (PARTITION BY ym_pv_clientID ORDER BY ym_pv_dateTime) IS NULL
THEN 1
ELSE 0
END AS is_new_session
FROM
test_artsoft_new),

t2 as (SELECT
ym_pv_clientID,
ym_pv_dateTime,
ym_pv_notBounce,
ym_pv_deviceCategory,
SUM(is_new_session) OVER (PARTITION BY ym_pv_clientID ORDER BY ym_pv_dateTime) AS session_id
FROM t), 

t3 as( 
select *, case
when duration > 0
then 1
when duration = 0
then (SELECT ym_pv_notBounce from test_artsoft_new tan where gg.ym_pv_clientID = tan.ym_pv_clientID
	 													and gg.session_start = tan.ym_pv_dateTime)
end notBounce
from
(SELECT
ym_pv_clientID,
session_id,
ym_pv_deviceCategory,
MIN(ym_pv_dateTime) AS session_start,
MAX(ym_pv_dateTime) AS session_end,
EXTRACT(EPOCH FROM MAX(ym_pv_dateTime) - MIN(ym_pv_dateTime)) AS duration									
FROM 
t2
GROUP BY
ym_pv_clientID, session_id,ym_pv_deviceCategory) gg
)


select avg(duration) from (SELECT * from t3 where notbounce = 1) t  /*avg(duration) = 148.4 sec*/



/*в таком подходе мы считаем время продолжительности сессии как время последнего действия - время первого действия
не учитывая время пользователя, которое он проводит, после последнего действия в сессии
давайте посчитаем среднее время между двумя последовательными действиями как 
суммарная длительность всех сессий / кол-во всех интервалов 
и добавим к времени каждой сессии, тогда и средняя продолжительность увеличится на эту же величину*/

/*select avg(cnt_intervals_per_session) from  
(select ym_pv_clientid, session_id, count(session_id) - 1 as cnt_intervals_per_session from t2
group by ym_pv_clientid, session_id
order by ym_pv_clientid, session_id) h   */    /* total intervals = 2123 */
 
select sum(duration) from t3 /* total duration = 138499  seconds */

select(138499 * 1.0 / 2123) as avg_time_of_interval   /* 65.24*/

/*таким образом avg_session_time = 148.4 + 65.24 =213.64*/



/*........3.......*/	
/*Сколько страниц автомобилей (страница конкретного автомобиля имеет
следующий вид и обычно называется VDP – vehicle details page) было
просмотрено с мобильных устройств и с компьютера.*/
select case
when ym_pv_deviceCategory = 1
then 'Декстоп'
when ym_pv_deviceCategory = 2
then 'Мобильные устройства'
when ym_pv_deviceCategory = 3
then 'Планештеы'
end device, cnt from 
(select ym_pv_deviceCategory, count(car_id) as cnt from 
(select * from test_artsoft_new) t
group by ym_pv_deviceCategory) t1

/*.......4.......*/
/*С каких источников трафика пришли клиенты.*/
select ym_pv_lastTrafficSource as TrafficSource, count(ym_pv_lastTrafficSource) as cnt from test_artsoft_new
group by ym_pv_lastTrafficSource
order by cnt DESC

/*5*/
/*Одна из основных метрик на сайте – VDP views. В нашем случае это
отношение просмотров страниц автомобиля ко всем просмотрам. Посчитайте
это отношение для уникальных пользователей в разрезе мобильных устройств
и компьютера, а также добавьте разрез по источникам трафика.*/
select 
case
when ym_pv_deviceCategory = 1
then 'Декстоп'
when ym_pv_deviceCategory = 2
then 'Мобильные устройства'
end device,
ROUND(car_views*1.0/total_views,2) VDP_views,
car_views as vdp,
total_views
from
(select ym_pv_deviceCategory, count(car_id) as car_views, count(*) as total_views from test_artsoft_new
group by ym_pv_deviceCategory
having ym_pv_deviceCategory = 1 or  ym_pv_deviceCategory=2) t
order by device

/* посчтитаем метрику avg(VDP_views) в разрезе мобильных телефонов и компьютеров и получаем, что
avg(VDP_views) = 0.065  для пк
avg(VDP_views) = 0.157  для мобильных */


/*........6........*/
/*Опишите своими словами, за что отвечает столбец ym_pv_notBounce.*/
/*позволяет понять достаточно ли долго пользователь провел времени на сайте после действия */
/*если, например, в сессии одно действие, и пользователь провел меньше определенного кол-ва времени, 
то считаем это отказом, и такие случаи надо отдельно обрабатывать*/

/*дополнительные запросы для визуализации*/

with t as(
SELECT
ym_pv_clientID,
ym_pv_dateTime,
ym_pv_notBounce,
ym_pv_deviceCategory,
CASE
WHEN ym_pv_dateTime - LAG(ym_pv_dateTime) OVER (PARTITION BY ym_pv_clientID ORDER BY ym_pv_dateTime) >= INTERVAL '30' MINUTE
OR LAG(ym_pv_dateTime) OVER (PARTITION BY ym_pv_clientID ORDER BY ym_pv_dateTime) IS NULL
THEN 1
ELSE 0
END AS is_new_session
FROM
test_artsoft_new),

t2 as (SELECT
ym_pv_clientID,
ym_pv_dateTime,
ym_pv_notBounce,
ym_pv_deviceCategory,
SUM(is_new_session) OVER (PARTITION BY ym_pv_clientID ORDER BY ym_pv_dateTime) AS session_id
FROM t), 

t3 as( 
select *, case
when duration > 0
then 1
when duration = 0
then (SELECT ym_pv_notBounce from test_artsoft_new tan where gg.ym_pv_clientID = tan.ym_pv_clientID
	 													and gg.session_start = tan.ym_pv_dateTime)
end notBounce
from
(SELECT
ym_pv_clientID,
session_id,
ym_pv_deviceCategory,
MIN(ym_pv_dateTime) AS session_start,
MAX(ym_pv_dateTime) AS session_end,
EXTRACT(EPOCH FROM MAX(ym_pv_dateTime) - MIN(ym_pv_dateTime)) AS duration									
FROM 
t2
GROUP BY
ym_pv_clientID, session_id,ym_pv_deviceCategory) gg
)


select case 
when ym_pv_deviceCategory = 1
then 'Десктоп'
when ym_pv_deviceCategory = 2
then 'Мобильные устройства'
when ym_pv_deviceCategory = 3
then 'Планшеты'
end as device, 
avg(duration) + 65.24 as avg_session_time 
from (SELECT * from t3 where notbounce = 1 ) t
group by ym_pv_deviceCategory   /* добавили среднее время интервала  (время последнего действия)*/




/*пользователи по странам*/
select ym_pv_regioncountry as country, 
case
when ym_pv_regioncity is null
then 'unkown city'
else ym_pv_regioncity
end city, 
count(distinct ym_pv_clientid ) as unique_user_count
from test_artsoft_new
group by ym_pv_regioncountry, ym_pv_regioncity
order by unique_user_count DESC

/*пользоватлеи по России и другим странам */
with t as(
select case 
when ym_pv_regioncountry = 'Russia'
then 'Russia'
else 'Other country'
end as country, 
case
when ym_pv_regioncity is null
then 'unkown city'
else ym_pv_regioncity
end city, 
count(distinct ym_pv_clientid ) as unique_user_count
from test_artsoft_new
group by ym_pv_regioncountry, ym_pv_regioncity
order by unique_user_count DESC),

cities as(
select city from t
where country = 'Russia'
order by unique_user_count desc
limit 6)

select country, 
case
when country='Russia' and not city in (SELECT * from cities)
then 'other cities'
else city
end as city,
unique_user_count from t
 
 
/*статистика по vdp по девайсам*/ 
select 
case
when ym_pv_deviceCategory = 1
then 'Декстоп'
when ym_pv_deviceCategory = 2
then 'Мобильные устройства'
end device,
ROUND(car_views*1.0/total_views,2) VDP_views,
car_views as vdp,
total_views
from
(select ym_pv_deviceCategory, count(car_id) as car_views, count(*) as total_views from test_artsoft_new
group by ym_pv_deviceCategory
having ym_pv_deviceCategory = 1 or  ym_pv_deviceCategory=2) t
order by device


