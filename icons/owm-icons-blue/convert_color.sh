#!/bin/bash

#
#   $1 source fuzz
#   $2 source color
#   $3 target color
#   $4 target file appendix
#   $5 source file
#

echo "$1 $2 -> $3 $4 $5"

for file in $5; do
    #echo "$file"
    base="$(basename "$file")"
    base="${base%.*}"
    #echo "$base"
    convert "$file" -fuzz "20%" -fill "$3" -opaque "$2" "./${base}${4}.png"
done

