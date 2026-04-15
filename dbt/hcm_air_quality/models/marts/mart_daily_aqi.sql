{{ config(materialized='table') }}

with historical as (
    select observed_at, us_aqi, european_aqi
    from {{ ref('stg_historical') }}
    where us_aqi is not null
),

hourly as (
    select
        date(observed_at)   as observed_at,
        avg(us_aqi)         as us_aqi,
        avg(european_aqi)   as european_aqi
    from {{ ref('stg_hourly') }}
    group by 1
),

combined as (
    select * from historical
    union all
    select * from hourly
),

aggregated as (
    select
        observed_at,
        round(avg(us_aqi), 1)       as us_aqi,
        round(avg(european_aqi), 1) as european_aqi
    from combined
    group by observed_at
),

final as (
    select
        observed_at,
        us_aqi,
        european_aqi,
        round(avg(us_aqi) over (
            order by observed_at
            rows between 6 preceding and current row
        ), 1) as us_aqi_7d_avg,
        case
            when us_aqi is null then 'Unknown'
            when us_aqi <= 50   then 'Good'
            when us_aqi <= 100  then 'Moderate'
            when us_aqi <= 150  then 'Unhealthy for Sensitive Groups'
            when us_aqi <= 200  then 'Unhealthy'
            when us_aqi <= 300  then 'Very Unhealthy'
            else 'Hazardous'
        end as aqi_category
    from aggregated
)

select * from final
order by observed_at