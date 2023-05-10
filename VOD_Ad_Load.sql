CREATE OR REPLACE TABLE `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_Beta` as

with SV as (select
adobe_tracking_id,
adobe_date,
extract(week from adobe_date) as Week,
case 
when device_name in ("Ios Mobile", "Amazon Fire Tablet", "Android Mobile") then "Mobile"
when device_name = "Www" then "Web"
else "TV" end as Devices, -- break down by TV / Mobile / Web
INITCAP(display_primary_genre) as Display_primary_genres,
case when lower(regexp_extract(display_secondary_genre, r'[^;,&]+')) in ('comedy','drama','documentary') 
     then lower(regexp_extract(display_secondary_genre, r'[^;,&]+'))  
     else "others" end as Primary_Genre, -- drama / comedy / documentary 
case when lower(display_secondary_genre) like "%sport%" or lower(display_secondary_genre) like "%premier%league%" then "Sports" -- Incl. premier league to sport
     when lower(display_secondary_genre) like "%kids%" then "Kids"
     when lower(display_secondary_genre) like "%wwe%" then "WWE"
     when lower(display_name) 
     in (SELECT distinct lower(program) FROM `nbcu-ds-prod-001.PeacockDataMartMarketingGold.GOLD_ORIGINALS_PRIMARY_KPIS` where base_date between current_date("America/New_York")-5 and current_date("America/New_York")-1) then "Tv-original" -- recent Highlight Originals
     Else 'Others' end as Secondary_Genre,
num_views_started,
display_secondary_genre,
ad_viewed,
ad_served,
promo_length,
case when promo_length < 15 then "<15S"
     when  promo_length < 30 then "15-30S" 
     when  promo_length < 60 then "30-60S"
     when  promo_length >= 60 then ">60S"
     else "" end -- Added logic to deal with null value
AS silver_Ad_Duration, --post_evar141 Creatibe Duration
promo_video_position AS Ad_Pod_Name, --post_evar143
num_seconds_played_with_ads,
num_seconds_played_no_ads
from `nbcu-ds-prod-001.PeacockDataMartSilver.SILVER_VIDEO`
where adobe_date between "2023-01-01" and "2023-05-08" and adobe_tracking_id is not null and lower(consumption_type_detail) = "vod"),

SU as (
select 
adobe_tracking_id,
report_date,
entitlement
from `nbcu-ds-prod-001.PeacockDataMartSilver.SILVER_USER`
where report_date between "2023-01-01" and "2023-05-08" and entitlement = "Premium"
),

Combination as (select SV.*,
case 
when (lower(Display_primary_genres) in ("tv","Sports","News") and Secondary_Genre = "WWE") or (lower(Devices) = "tv" and Secondary_Genre = "WWE") then "Tv-WWE" -- Display_Primary_Genre are all Sports for WWE, so I set up 2nd clause using devices
when (lower(Display_primary_genres) in ("tv","Sports","News") and Secondary_Genre = "Sports") then "Tv-Sports"
when (lower(Display_primary_genres) in ("tv","Sports","News") and Secondary_Genre = "Kids") then "Tv-Kids"
when lower(Display_primary_genres) = "movies" and Secondary_Genre = "Kids" then "Movies-kids"
when Secondary_Genre = "Tv-original" then "Tv-originals"
when lower(Display_primary_genres) = "movies" and Secondary_Genre != "Kids" then "Movies"
else "Tv-Others" end as Content_Types,
SU.entitlement as Account_Entitlement,
case when ad_served = 1 then promo_length else 0 end as Ad_Time_Watched -- ad_served (Ad completed) then ad watched, so ad length is ad time
from SV
inner join SU on SV.adobe_date = SU.report_date and SV.adobe_tracking_id = SU.adobe_tracking_id), -- Only care about "Premium" tier

Alls as (select 
adobe_date,
Account_Entitlement,
extract(week from adobe_date) as Week,
Devices,
Primary_Genre,
Content_Types,
silver_Ad_Duration, --Duration brkdwn
sum(num_views_started) as Content_Start,
round(sum(ad_viewed),0) as Ad_Unit,
round(sum(Ad_Time_Watched)/60,0) as Ad_Minutes_Watched,
round(sum(num_seconds_played_no_ads)/3600,2) as Hours_Watched
from Combination 
group by 1,2,3,4,5,6,7
)

select a.*,
ifnull(round(safe_divide(CAST(a.Ad_Unit AS DECIMAL), CAST(a.Hours_Watched AS DECIMAL)),2),0) as Ad_Unit_per_Hour,
ifnull(round(safe_divide(CAST(a.Ad_Minutes_Watched AS DECIMAL), CAST(a.Hours_Watched AS DECIMAL)),2),0) as Ad_Minutes_Watched_per_Hour
from Alls a
order by 1 desc
