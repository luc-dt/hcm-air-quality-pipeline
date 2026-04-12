{{ config(materialized='table') }}

with historical as (
    select
        observed_at,
        pm10,
        pm2_5,
        carbon_monoxide,
        nitrogen_dioxide,
        sulphur_dioxide,
        ozone
    from {{ ref('stg_historical') }}
),

hourly as (
    select
        date(observed_at)         as observed_at,
        round(avg(pm10), 2)       as pm10,
        round(avg(pm2_5), 2)      as pm2_5,
        round(avg(carbon_monoxide), 2)   as carbon_monoxide,
        round(avg(nitrogen_dioxide), 2)  as nitrogen_dioxide,
        round(avg(sulphur_dioxide), 2)   as sulphur_dioxide,
        round(avg(ozone), 2)      as ozone
    from {{ ref('stg_hourly') }}
    group by 1
),

final as (
    select * from historical
    union all
    select * from hourly
)

select * from final
order by observed_at

