{{ config(materialized='view') }}

select
    parse_date('%Y-%m-%d', date)  as observed_at,
    pm10,
    pm2_5,
    carbon_monoxide,
    nitrogen_dioxide,
    sulphur_dioxide,
    ozone,
    us_aqi,
    european_aqi
from {{ source('raw', 'raw_historical') }}
where date is not null