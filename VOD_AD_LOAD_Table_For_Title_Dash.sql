

create or replace table `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_Table_For_Title_Dash` as 

with content_type_rk as (select 
Display_Name,
lower(Content_Types) as Content_Types,
dense_rank() over (partition by Display_Name order by round(sum(num_seconds_played_with_ads)/3600,2) desc) as rk
from `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_Table` 
group by 1,2),

content_type_match as (select Display_Name,
Content_Types
from content_type_rk
where rk=1) -- get rid of mutiple Content type noises 

select 
adobe_date,
Account_Entitlement,
Week,
t.Display_Name,
set_duration,
Devices,
trim(Primary_Genre) as Primary_Genre, -- remove whitespace
case when lower(t.Content_Types) = "tv-originals" then "TV-Originals"
when lower(t.Content_Types) = "tv-wwe" then "TV-Wwe"
when lower(t.Content_Types) = "tv-others" then "TV-Others"
when lower(t.Content_Types) = "tv-kids" then "TV-Kids"
when lower(t.Content_Types) = "movies-kids" then "Movies-Kids"
when lower(t.Content_Types) = "tv-sports" then "TV-Sports"
when lower(t.Content_Types) = "movies" then "Movies"
ELSE lower(t.Content_Types) end as Content_Type, --- need to be adjusted to the same case format to other tab
Ad_Pod_Name,
sum(num_views_started) as Content_Start,
round(sum(ad_viewed),0) as Ad_Unit,
round(sum(Ad_Time_Watched)/60,0) as Ad_Minutes_Watched,
round(sum(num_seconds_played_with_ads)/3600,2) as Hours_Watched
from 
`nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_Table` t
inner join content_type_match c on c.Display_Name = t.Display_Name and lower(c.Content_Types) = lower(t.Content_Types)
group by 1,2,3,4,5,6,7,8,9;



