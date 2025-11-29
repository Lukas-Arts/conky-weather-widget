#!/bin/bash

# if more than 5 mins since last call have passed, get & update
# weather info from https://wttr.in or https://open-meteo.com and radar image from dwd.de

weatherinfo=""
last_update=0
if [ -f "$HOME/.conky/weather-widget/last_update.txt" ]; then
    last_update=$(cat "$HOME/.conky/weather-widget/last_update.txt")
    #echo "found last_update.txt. last update was: $last_update" >> "$HOME/.conky/weather-widget/weather.log"
fi
my_now=$(date +%s)
if ((my_now-last_update < 300)) then
    #echo "no update needed. reading old weather info..." >> "$HOME/.conky/weather-widget/weather.log"
    
    weatherinfo=$(cat "$HOME/.conky/weather-widget/weatherinfo.json")
else
    #echo "realoading weather data $(date +%T) $my_now  $last_update  $((my_now-last_update))" >> "$HOME/.conky/weather-widget/weather.log"

    
    get_and_crop_radar_log=$($HOME/.conky/weather-widget/get_and_crop_radar_image.sh "hes")
    
    #echo "no previous update found, or too old. updating weather info..."
    #echo "using $1"
    if [ "$1" == "wttr" ]; then
        #echo "using wttr"
        weatherinfo=$(curl  -H "Accept-Encoding: gzip,deflate" -s "https://wttr.in/$2?format=j1&lang=de")
        printf "$weatherinfo" > "$HOME/.conky/weather-widget/weatherinfo.json"
    elif [ "$1" == "open-meteo" ]; then
        #echo "using open-meteo"
        url="https://api.open-meteo.com/v1/forecast?latitude=$2&longitude=$3&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunshine_duration,daylight_duration,rain_sum,showers_sum,snowfall_sum,precipitation_sum,precipitation_hours,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,temperature_2m_mean,apparent_temperature_mean,precipitation_probability_mean,sunrise,sunset,relative_humidity_2m_mean,visibility_mean,wind_speed_10m_mean,wind_gusts_10m_mean,surface_pressure_mean&hourly=precipitation_probability,weather_code,relative_humidity_2m,apparent_temperature,dew_point_2m,cloud_cover,visibility,is_day,temperature_2m&current=weather_code,temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl,surface_pressure&minutely_15=temperature_2m,relative_humidity_2m,apparent_temperature,sunshine_duration,weather_code,visibility,is_day&timezone=Europe%2FBerlin&forecast_minutely_15=96"
        weatherinfo=$(curl -s "$url")
        printf "%s" $weatherinfo > "$HOME/.conky/weather-widget/weatherinfo.json"
    fi
    
    
    last_update=$my_now
    printf "$last_update" > "$HOME/.conky/weather-widget/last_update.txt"
fi

if [ -z "$weatherinfo" ]; then
    echo -n "\${color9}Error in Weather-Service!\${color1}"
fi
