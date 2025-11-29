# Conky Weather Widget

A Weather Widget for [Conky](https://github.com/brndnmtthws/conky) using [wttr.in](https://github.com/chubin/wttr.in) or [open-meteo.com](https://open-meteo.com) for Weather-Data and [dwd.de](https://dwd.de) for Rain Radar Images from Germany.

 ![Conky Weather Widget Preview](./weather.conky.png)

The Charts show the baseline Temperature in light blue with an randomly estimated error rate, filled in a darker blue. The orange line indicates the chance of precipitation and the single darker blue line the humidity. The vertical red line shows the current time. 

The Radar Image is shown as an animation of the Images from the last 60 minutes.

Icons are based on [OpenWeatherMap Icons](https://github.com/rodrigokamada/openweathermap)

## General Setup

Move these files to `~/.conky/weather-widget/`. Then install lua-json and imagemagick.

    sudo apt install lua-json
    sudo apt install imagemagick


## Setup Weather Data

You can choose between wttr.in and open-meteo.com as Providers for the Weather Data. For Europe, open-meteo seems to be the better provider.

### wttr.in

`wttr.in` tries to fetch the right Weather Info based on you IP by default. If that isn't sufficient, you can add the Location at the end of the `texecpi`-command. To use the widget, edit the `weather.conky`: 

    lua_load = '~/.conky/weather-widget/lua/WttrWeatherWidget.lua'

and

    ${texecpi 60 ~/.conky/weather-widget/weather.sh wttr YOUR_LOCATION_NAME}

### open-meteo.com

For `open-meteo.com` you need to specify your Lat/Lon coordinates. You might want to search for the correct coordinates using https://open-meteo.com/en/docs as open-meteo seems to map the coordinates to those of the nearest station witch might not always be the best fit. Edit in the weather.conky

    lua_load = '~/.conky/weather-widget/lua/OpenMeteoWeatherWidget.lua'

and

    ${texecpi 60 ~/.conky/weather-widget/weather.sh open-meteo LATITUDE LONGITUDE}

## Setup Radar View

To set up the Radar View edit the `weather.sh` and specify your `REGION` in line 21:

    get_and_crop_radar_log=$($HOME/.conky/weather-widget/get_and_crop_radar_image.sh "REGION" "DETAIL_VIEW_X" "DETAIL_VIEW_Y")

For available `REGION`s check the [DWD Homepage](https://www.dwd.de/DE/leistungen/radarbild_film/radarbild_film.html)

If `DETAIL_VIEW_X` and `DETAIL_VIEW_Y` are specified, a 3x zoomed, 150x150px detail view from the specified coordinates will be shown in the upper left corner (see preview).

Also edit the `./lua/WttrWeatherWidget.lua` at line 123 & 124 to show a target indicator at your location:

    local target_x = %YOUR_HOME_X% + x
    local target_y = %YOUR_HOME_Y% + y

## Temp Folders and Files

You might need to create these Folders for the Radar Images:

    ./gif_frames
    ./gif_frames_edit
    ./gif_frames_raw

And these Files:

    ./weatherinfo.json
    ./last_update.txt

## Changing the Colors

You can use the `./icons/owm-icons-blue/convert_color.sh`, `./icons/owm-icons-blue/convert_color.sh` and `./icons/arrow/rotate_img.sh` scripts to bulk edit the icon colors. Then edit the `./weather.conky` and `.lua` files in `./lua/`
