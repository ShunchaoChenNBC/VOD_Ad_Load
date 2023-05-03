CREATE OR REPLACE TABLE `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_ALPHA_V1` as

with SV as (select
adobe_tracking_id,
adobe_date,
extract(week from adobe_date) as Week,
case 
when device_platform like "%tv%" or device_platform = "Settop" then "TV"
when device_platform in ("Mobile App","Ios") then "Mobile"
else "Others" end as Devices, -- break down by TV / Mobile / Others
INITCAP(display_primary_genre) as Display_primary_genres,
case when lower(regexp_extract(display_secondary_genre, r'[^;,&]+')) in ('comedy','drama','documentary') 
     then lower(regexp_extract(display_secondary_genre, r'[^;,&]+'))  
     else "others" end as Primary_Genre, -- drama / comedy / documentary 
case when lower(display_secondary_genre) like "%sport%" or lower(display_secondary_genre) like "%premier%league%" then "Sports" -- Incl. premier league to sport
     when lower(display_secondary_genre) like "%kids%" then "Kids"
     when lower(display_secondary_genre) like "%wwe%" then "WWE"
     Else 'Others' end as Secondary_Genre,
num_views_started,
display_secondary_genre,
ad_viewed,
ad_id,
num_seconds_played_with_ads,
num_seconds_played_no_ads
from `nbcu-ds-prod-001.PeacockDataMartSilver.SILVER_VIDEO`
where adobe_date between "2023-04-01" and "2023-04-10" and adobe_tracking_id is not null and lower(consumption_type_detail) = "vod"),

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
when (lower(Display_primary_genres) = "tv" and Secondary_Genre = "WWE") or (lower(Devices) = "tv" and Secondary_Genre = "WWE") then "Tv-WWE" -- Display_Primary_Genre are all Sports for WWE, so I set up 2nd clause using devices
when (lower(Display_primary_genres) = "tv" and Secondary_Genre = "Sports") then "Tv-Sports"
when (lower(Display_primary_genres) = "tv" and Secondary_Genre = "Kids") then "Tv-Kids"
when lower(Display_primary_genres) = "movies" and Secondary_Genre = "Kids" then "Movies-kids"
when (lower(Display_primary_genres) = "tv" and Secondary_Genre not in ("WWE","Sports","Kids")) or (lower(Devices) = "tv" and Secondary_Genre not in ("WWE","Sports","Kids")) then "Tv-originals"
when lower(Display_primary_genres) = "movies" or Secondary_Genre != "Kids" then "Movies"
else "Others" end as Content_Types,
SU.entitlement as Account_Entitlement
from SV
inner join SU on SV.adobe_date = SU.report_date and SV.adobe_tracking_id = SU.adobe_tracking_id), -- Only care about "Premium" tier

Alls as (select 
adobe_date,
Account_Entitlement,
extract(week from adobe_date) as Week,
Devices,
Primary_Genre,
Content_Types,
sum(num_views_started) as Content_Start,
round(sum(ad_viewed),0) as Ad_Unit,
round((sum(num_seconds_played_with_ads)- sum(num_seconds_played_no_ads))/60,0) as Ad_Minutes_Watched,
round(sum(num_seconds_played_no_ads)/3600,2) as Hours_Watched,
sum(ad_viewed) as Ad_Pods_Watched
from Combination 
group by 1,2,3,4,5,6)

select a.*,
ifnull(round(safe_divide(CAST(a.Ad_Unit AS DECIMAL), CAST(a.Hours_Watched AS DECIMAL)),2),0) as Ad_Unit_per_Hour,
ifnull(round(safe_divide(CAST(a.Ad_Minutes_Watched AS DECIMAL), CAST(a.Hours_Watched AS DECIMAL)),2),0) as Ad_Minutes_Watched_per_Hour
from Alls a
order by 1 desc
