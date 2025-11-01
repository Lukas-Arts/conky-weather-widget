#!/bin/bash


for i in $(seq 1 $3)
do
    filename=$(basename -- "$1")
    filename="${filename%.*}"
    deg="$(($2*$i))"
    convert "$1" -distort SRT "$deg" "$filename-$deg.png"; 
done

