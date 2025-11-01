#!/bin/bash

# if more than 5 mins since last call have passed, get & update
# weather info from wttr.in and radar image from dwd.de

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
    
    weatherinfo=$(curl -s "https://wttr.in/$1?format=j1&lang=de")
    printf "$weatherinfo" > "$HOME/.conky/weather-widget/weatherinfo.json"
    
    last_update=$my_now
    printf "$last_update" > "$HOME/.conky/weather-widget/last_update.txt"
fi

if [ -z "$weatherinfo" ]; then
    echo -n "\${color9}Error in Weather-Service!\${color1}"
fi
