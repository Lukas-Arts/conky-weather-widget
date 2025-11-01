#!/bin/bash

# this script retrieves the latest radar image of region $1 from https://www.dwd.de/DWD/wetter/radar/rad_${1}_akt.jpg .
# See https://www.dwd.de/DE/leistungen/radarbild_film/radarbild_film.html for available images.
# for hes it cuts the image to fit better. this results in a 400x400 image instead of 540x500
# A 50x50 Detail Part at x = $2, y = $3 (top left) is cut out, zoomed to 150x150, and pasted at the top left corner, 
# if these values are set.

# get latest radar image
img="$HOME/.conky/weather-widget/gif_frames_raw/latest_radar_view.png"
curl -m 30 -s "https://www.dwd.de/DWD/wetter/radar/rad_${1}_akt.jpg" > "$img"
datetime=$(date +%F_%H-%M)

# alternatively get latest radar gif
# curl -m 30 -s "https://www.dwd.de/DWD/wetter/radar/radfilm_${1}_akt.gif" > "$HOME/.conky/weather-widget/radfilm_${1}_akt.gif"
# convert gif into png-frames
# ffmpeg -i "$HOME/.conky/weather-widget/radfilm_${1}_akt.gif" "$HOME/.conky/weather-widget/gif_frames_raw/frame_%03d.png"


filename=$(basename "$img")

# get dimensions
read width height < <(identify -format "%w %h" "$img")

crop_x=0
crop_y=$((height - 21))    # start 21px from bottom
move_x=225                 # pixels to the right
move_y=-100                # pixels up (negative moves up)
opacity=0.75                # 0..1 (1 = opaque)
target_x=192
part_file="$HOME/.conky/weather-widget/gif_frames_edit/part_${filename}"
detail_part_file="$HOME/.conky/weather-widget/gif_frames_edit/detail_part_${filename}"
comp_file="$HOME/.conky/weather-widget/gif_frames_edit/comp_$filename"
cropped_file="$HOME/.conky/weather-widget/gif_frames_edit/cropped_$filename"
final_file="$HOME/.conky/weather-widget/gif_frames/${datetime}.png"

echo "Processing $filename (${width}x${height})"

if [ "$1" == "hes" ]; then
    echo "Cropping Part $filename -> $part_file"
    convert "$img" -crop "230x21+${crop_x}+${crop_y}" +repage "$part_file"
    echo "Adjusting transparency on part: $part_file"
    convert "$part_file" -alpha set -channel A -evaluate Multiply $opacity +channel "$part_file"
fi

# crop & resize detail view if $2 is specified
if [ -n "$2" ]; then
    echo "Cropping Detail-Part $filename at ${2}/${3} -> $part_file"
    convert "$img" -crop "50x50+${2}+${3}" +repage "$detail_part_file"
    echo "Resizing Detail-Part: $detail_part_file"
    convert -resize 150x150 "$detail_part_file" "$detail_part_file"
fi

if [ "$1" == "hes" ]; then
    pos_x=$((0 + move_x))
    pos_y=$((crop_y + move_y))
    if (( pos_y < 0 )); then pos_y=0; fi
    echo "Compositing (+${pos_x}/+${pos_y}) $part_file onto $img -> $out_file "

    convert "$img" "$part_file" -geometry +${pos_x}+${pos_y} -composite "$comp_file"

    # add detail view if $2 is specified
    if [ -n "$2" ]; then
        echo "Compositing Detail-Part (+140/+0) $part_file onto $img -> $out_file "

        convert "$comp_file" "$detail_part_file" -geometry +140+0 -composite "$comp_file"
    fi

    echo "Cropping $filename -> $part_file"
    convert "$comp_file" -crop "400x400+140+0" +repage "$cropped_file"
else
    # add detail view if $2 is specified
    if [ -n "$2" ]; then
        echo "Compositing Detail-Part (+0/+0) $part_file onto $img -> $out_file "

        convert "$img" "$detail_part_file" -geometry +0+0 -composite "$cropped_file"
    else
        cp "$img" "$cropped_file"
    fi

fi

echo "Adjusting transparency for final: $cropped_file"
convert "$cropped_file" -alpha set -channel A -evaluate Multiply 0.25 +channel "$final_file"

# delete files from 60min before now
find $HOME/.conky/weather-widget/gif_frames/* -mmin +60 -printf "removed '%f'\n" -delete    


