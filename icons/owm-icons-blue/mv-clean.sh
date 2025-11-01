#!/bin/bash

#
#   $1 resize in percent
#   $2 source file remove appendix
#   $3 target file appendix
#   $4 source file
#

echo "$1 $2"


for file in $1; do
    #echo "$file"
    base="$(basename "$file")"
    base="${base//$2/}"
    base="${base%.*}"
    #echo "$base"
    if [[ $file =~ '0-blue0.5x-blue.png' ]]; then
        mv $file "./${base}0.5x-blue.png"
    fi
done;
