UPDATE  `nbcu-ds-sandbox-a-001.Shunchao_Sandbox.VOD_AD_LOAD_Table_For_Dash`
SET Content_Types = case
    when Content_Types = "Tv-originals" then "TV-Originals"
    when Content_Types = "Tv-WWE" then "TV-Wwe"
    when Content_Types = "Tv-Others" then "TV-Others"
    when Content_Types = "Tv-Kids" then "TV-Kids"
    when Content_Types = "Movies-kids" then "Movies-Kids"
    when Content_Types = "Tv-Sports" then "TV-Sports"
    ELSE Content_Types
END
WHERE Content_Types != ""
