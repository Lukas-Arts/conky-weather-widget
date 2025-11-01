#!/bin/bash

#
#   $1 resize in percent
#   $2 source file remove appendix
#   $3 target file appendix
#   $4 source file
#

echo "$1 $2 $3 $4"

for file in $4; do
    #echo "$file"
    base="$(basename "$file")"
    base="${base//$2/}"
    base="${base%.*}"
    #echo "$base"
    convert "$file" -resize "$1" "./${base}${3}.png"
done

