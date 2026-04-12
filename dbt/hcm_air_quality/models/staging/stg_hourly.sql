{{ config(materialized='view') }}

select
    parse_timestamp('%Y-%m-%dT%H:%M', timestamp) as observed_at,
    pm10,
    pm2_5,
    carbon_monoxide,
    nitrogen_dioxide,
    sulphur_dioxide,
    ozone,
    us_aqi,
    european_aqi,
    date,
    hour,
    ingested_at
from {{ source('raw', 'raw_hourly') }}
where timestamp is not null