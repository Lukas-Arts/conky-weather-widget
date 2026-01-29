#!/bin/bash

# this script retrieves the latest satellite image from 
# https://view.eumetsat.int/geoserver/ows?service=WMS&request=GetMap&version=1.3.0&layers=mtg_fd:rgb_geocolour,ne_10m_admin_0_boundary_lines_land,backgrounds:ne_10m_coastline&styles=&format=image/jpeg&crs=EPSG:4326&bbox=30,-13,65,40&width=800&height=800 .
# This request will get the latest image for the GeoColour RGB - MTG - 0 degree layer as shown here: https://view.eumetsat.int/productviewer/productDetails/mtg_fd:rgb_geocolour?v=mtg_fd:rgb_geocolour (click on the little (i) icon for "Product Information" besides the layer and "Sample GetMap request" for a sample request with tat layer)
# See https://user.eumetsat.int/resources/user-guides/eumet-view-user-guide#ID-Using-the-APIs for more infos about using the eumetsat api.


# get latest satellite image
datetime=$(date +%F_%H:%M)
img="$HOME/.conky/weather-widget/eu_gif_frames/$datetime.png"
timestampImg="$HOME/.conky/weather-widget/eu_gif_frames_raw/timestampImg.png"
latest="$HOME/.conky/weather-widget/eu_gif_frames_raw/latest.jpeg"
transparent="$HOME/.conky/weather-widget/eu_gif_frames_raw/transparent.png"
# get image from eumetsat api
curl -H "Accept-Encoding: gzip,deflate" -m 30 -s "https://view.eumetsat.int/geoserver/ows?service=WMS&request=GetMap&version=1.3.0&layers=mtg_fd:rgb_geocolour,ne_10m_admin_0_boundary_lines_land,backgrounds:ne_10m_coastline&styles=&format=image/jpeg&crs=EPSG:4326&bbox=30,-13,65,40&width=400&height=400" > "$latest"
datetime2=${datetime/_/ }

# make transparent
convert "$latest" -alpha set -channel A -evaluate Multiply 0.25 +channel "$transparent"
# draw timestamp to transparent background
convert -size 230x21 xc:transparent -font 'Ubuntu-Mono' -pointsize 16 -fill '#3B5969FF' -draw "text 44,18 '$datetime2'" $timestampImg
# combine timestamp with transparent image
convert "$transparent" "$timestampImg" -geometry +85+379 -composite "$img"

# delete files from 60min before now
find $HOME/.conky/weather-widget/eu_gif_frames/* -mmin +120 -printf "removed '%f'\n" -delete
