with SV as (select 
adobe_tracking_id,
adobe_date,
extract(week from adobe_date) as Week,
INITCAP(display_primary_genre) as Display_primary_genres,
case when lower(regexp_extract(display_secondary_genre, r'[^;,&]+')) in ('comedy','drama','documentary') 
     then lower(regexp_extract(display_secondary_genre, r'[^;,&]+')) 
     else "others" end as Primary_Genre,
case when lower(regexp_extract(display_secondary_genre, r'[^;,&]+')) in ('sports','kids','wwe') 
     then lower(regexp_extract(display_secondary_genre, r'[^;,&]+'))
     when lower(regexp_extract(display_secondary_genre, r'[^;,&]+')) = "premier league" 
     then 'sports' -- Incl. premier league to sport
else "others" end as Secondary_Genre,
num_views_started,
ad_viewed,
num_seconds_played_with_ads,
num_seconds_played_no_ads
from `nbcu-ds-prod-001.PeacockDataMartSilver.SILVER_VIDEO`
where adobe_date between "2023-04-01" and "2023-04-10"),

SU as (
select 
adobe_tracking_id,
report_date,
entitlement
from `nbcu-ds-prod-001.PeacockDataMartSilver.SILVER_USER`
where report_date between "2023-04-01" and "2023-04-10" and entitlement = "Premium"
),

Combination as (select SV.*,
case 
when lower(Display_primary_genres) = "tv" then "tv-originals"
when lower(Display_primary_genres) = "movies" then "movies"
when lower(Display_primary_genres) = "tv" and Secondary_Genre = "wwe" then "tv-wwe"
when lower(Display_primary_genres) = "tv" and Secondary_Genre = "sports" then "tv-sports"
when lower(Display_primary_genres) = "tv" and Secondary_Genre = "kids" then "tv-kids"
when lower(Display_primary_genres) = "movies" and Secondary_Genre = "kids" then "movies-kids"
else "others" end as Content_Types,
SU.entitlement as Account_Entitlement
from SV
inner join SU on SV.adobe_date = SU.report_date and SV.adobe_tracking_id = SU.adobe_tracking_id)


select 
adobe_date,
Account_Entitlement,
extract(week from adobe_date) as Week,
Primary_Genre,
Content_Types,
sum(num_views_started) as Content_Start,
round(sum(ad_viewed),0) as Ad_Unit,
round((sum(num_seconds_played_with_ads)- sum(num_seconds_played_no_ads))/60,0) as Ad_Minutes_Watched
from Combination 
group by 1,2,3,4,5
order by 1 desc








