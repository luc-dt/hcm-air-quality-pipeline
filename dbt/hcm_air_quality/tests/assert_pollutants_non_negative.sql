select *
from {{ ref('mart_pollutants') }}
where pm2_5 < 0
   or pm10 < 0
   or ozone < 0
   or carbon_monoxide < 0
   or nitrogen_dioxide < 0
   or sulphur_dioxide < 0