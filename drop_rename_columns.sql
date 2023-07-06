--- Create a new column first

create or replace table  `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_Table_For_Dash` as 
select 
*,
case
    when set_duration = 20 then "20-39"
    when set_duration = 40 then "40-59"
    when set_duration = 60 then "60-89"
    when set_duration = 90 then "90-119"
    when set_duration = 120 then "120-149"
    When set_duration = 210 then "210-239"
    When set_duration = 240 then "240-269"
    ELSE cast(set_duration as string)
END as set_duration_str
from `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_Table_For_Dash`

-- drop the original column
ALTER TABLE `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_Table_For_Dash`
drop COLUMN IF EXISTS set_duration

-- rename to new column to the old
ALTER TABLE `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_Table_For_Dash`
rename COLUMN IF EXISTS set_duration_str to set_duration
