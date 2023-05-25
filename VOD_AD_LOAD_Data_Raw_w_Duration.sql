CREATE OR REPLACE TABLE `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_Data_Raw_w_Duration` as

with SV as (select
adobe_tracking_id,
adobe_date,
extract(week from adobe_date) as Week,
case 
when device_name in ("Ios Mobile", "Amazon Fire Tablet", "Android Mobile") then "Mobile"
when device_name = "Www" then "Web"
else "TV" end as Devices, -- break down by TV / Mobile / Web
INITCAP(display_primary_genre) as Display_primary_genres,
lower(regexp_extract(display_secondary_genre, r'[^;,&]+')) as Primary_Genre, -- first entry before semi-commas
case when lower(display_secondary_genre) like "%sport%" or lower(display_secondary_genre) like "%premier%league%" then "Sports" -- Incl. premier league to sport
     when lower(display_secondary_genre) like "%kids%" then "Kids"
     when lower(display_secondary_genre) like "%wwe%" then "WWE"
     when lower(s.display_name) 
     in (SELECT distinct lower(program) FROM `nbcu-ds-prod-001.PeacockDataMartMarketingGold.GOLD_ORIGINALS_PRIMARY_KPIS` where base_date between current_date("America/New_York")-5 and current_date("America/New_York")-1) then "Tv-original" -- recent Highlight Originals
     Else 'Others' end as Secondary_Genre,
num_views_started,
display_secondary_genre,
franchise,
lower(s.display_name) as Display_Name,
a.Set_duration,
ad_viewed,
ad_served,
promo_length,
case when promo_length < 12 then "<12S"
     when  promo_length <= 20 then "15S" 
     when  promo_length <= 40 then "30S"
     when  promo_length <= 65 then "60S"
     when  promo_length <= 80 then "75S"
     when  promo_length <= 95 then "90S"
     when  promo_length > 95 then ">95"    
     else "" end
AS silver_Ad_Duration, --post_evar141 Creatibe Duration
promo_video_position AS Ad_Pod_Name, --post_evar143
num_seconds_played_with_ads,
num_seconds_played_no_ads
from `nbcu-ds-prod-001.PeacockDataMartSilver.SILVER_VIDEO` s
left join (select Display_Name, Set_duration from  `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.Top_TV_VOD_Premium_Accounts` where Display_Name is not null) a on lower(a.Display_Name) = lower(s.display_name)
where adobe_date between "2023-02-01" and "2023-03-31" and adobe_tracking_id is not null and lower(consumption_type_detail) = "vod"),

SU as (
select 
adobe_tracking_id,
report_date,
entitlement
from `nbcu-ds-prod-001.PeacockDataMartSilver.SILVER_USER`
where report_date between "2023-02-01" and "2023-03-31" and entitlement = "Premium"
group by 1,2,3 -- group by to reduce data size
),

Combination as (select SV.*,
case 
when lower(franchise) = "wwe" then "Tv-WWE"  -- keep all franchise wwe to make sure number is the same as that on PAVO dash
when (lower(Display_primary_genres) in ("tv","Sports","News") and Secondary_Genre = "Sports") then "Tv-Sports"
when (lower(Display_primary_genres) in ("tv","Sports","News") and Secondary_Genre = "Kids") then "Tv-Kids"
when lower(Display_primary_genres) = "movies" and Secondary_Genre = "Kids" then "Movies-kids"
when Secondary_Genre = "Tv-original" then "Tv-originals"
when lower(Display_primary_genres) = "movies" and Secondary_Genre != "Kids" then "Movies"
else "Tv-Others" end as Content_Types,
SU.entitlement as Account_Entitlement,
num_seconds_played_with_ads - num_seconds_played_no_ads as Ad_Time_Watched -- with_ad minus without ad to get ad time watched
from SV
inner join SU on SV.adobe_date = SU.report_date and SV.adobe_tracking_id = SU.adobe_tracking_id) 

select *
from Combination
union all
select *
from  `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_Data_Raw_w_Duration`
