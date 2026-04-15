select *
from {{ ref('mart_daily_aqi') }}
where us_aqi is not null
  and (us_aqi < 0 or us_aqi > 500)