#!/bin/bash
#
# ffmpeg video slideshow script for advanced photo collection v3 (25.05.2019)
#
# Copyright (c) 2017-2019, Taner Sener (https://github.com/tanersener)
#
# This work is licensed under the terms of the MIT license. For a copy, see <https://opensource.org/licenses/MIT>.
#

# SCRIPT OPTIONS - CAN BE MODIFIED
WIDTH=1280
HEIGHT=720
FPS=30
TRANSITION_DURATION=1
PHOTO_DURATION=2
MAX_PHOTO_ANGLE=25
BACKGROUND_COLOR="#00000000"

IFS=$'\t\n'                 # REQUIRED TO SUPPORT SPACES IN FILE NAMES

# FILE OPTIONS
# FILES=`find ../media/*.jpg | sort -r`                 # USE ALL IMAGES UNDER THE media FOLDER SORTED
# FILES=('../media/1.jpg' '../media/2.jpg')         # USE ONLY THESE IMAGE FILES
FILES=`find ../media/*.jpg`                         # USE ALL IMAGES UNDER THE media FOLDER

############################
# DO NO MODIFY LINES BELOW
############################

# CALCULATE LENGTH MANUALLY
let PHOTOS_COUNT=0
for photo in ${FILES[@]}; do (( PHOTOS_COUNT+=1 )); done

if [[ ${PHOTOS_COUNT} -lt 2 ]]; then
    echo "Error: photos folder should contain at least two photos"
    exit 1;
fi

# INTERNAL VARIABLES
TRANSITION_FRAME_COUNT=$(( TRANSITION_DURATION*FPS ))
PHOTO_FRAME_COUNT=$(( PHOTO_DURATION*FPS ))
TOTAL_DURATION=$(( (PHOTO_DURATION+TRANSITION_DURATION)*PHOTOS_COUNT - TRANSITION_DURATION ))
TOTAL_FRAME_COUNT=$(( TOTAL_DURATION*FPS ))

echo -e "\nVideo Slideshow Info\n------------------------\nPhoto count: ${PHOTOS_COUNT}\nDimension: ${WIDTH}x${HEIGHT}\nFPS: ${FPS}\nPhoto duration: ${PHOTO_DURATION} s\n\
Transition duration: ${TRANSITION_DURATION} s\nTotal duration: ${TOTAL_DURATION} s\n"

START_TIME=$SECONDS

# 1. START COMMAND
FULL_SCRIPT="ffmpeg -y "

# 2. ADD INPUTS
for photo in ${FILES[@]}; do
    FULL_SCRIPT+="-loop 1 -i '${photo}' "
done

# 3. ADD BACKGROUND COLOR SCREEN INPUT
FULL_SCRIPT+="-f lavfi -i color=${BACKGROUND_COLOR}:s=${WIDTH}x${HEIGHT},fps=${FPS} "

# 4. START FILTER COMPLEX
FULL_SCRIPT+="-filter_complex \""

# 5. PREPARE BACKGROUND
FULL_SCRIPT+="[${PHOTOS_COUNT}:v]trim=duration=${TOTAL_DURATION}[stream0collected];"

# 6. PREPARE INPUTS
for (( c=0; c<${PHOTOS_COUNT}; c++ ))
do
    FULL_SCRIPT+="[${c}:v]setpts=PTS-STARTPTS,scale=w='if(gte(iw/ih,${WIDTH}/${HEIGHT}),min(iw,${WIDTH}),-1)':h='if(gte(iw/ih,${WIDTH}/${HEIGHT}),-1,min(ih,${HEIGHT}))',scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=sar=1/1,fps=${FPS},format=rgba,pad=width=$((WIDTH*4)):height=${HEIGHT}:x=($((WIDTH*4))-iw)/2:y=(${HEIGHT}-ih)/2:color=#00000000,trim=duration=$(( (c+1)*(TRANSITION_DURATION+PHOTO_DURATION) )),setpts=PTS-STARTPTS[stream$((c+1))];"

    ANGLE_RANDOMNESS=$(( (RANDOM % MAX_PHOTO_ANGLE) + 1 ));

    FULL_SCRIPT+="[stream$((c+1))]rotate=if(between(t\,$(( (TRANSITION_DURATION+PHOTO_DURATION)*c ))\,$(( (TRANSITION_DURATION+PHOTO_DURATION)*c+TRANSITION_DURATION )))\,2*PI*t+if(eq(mod(${c}\,2)\,0)\,1\,-1)*${ANGLE_RANDOMNESS}*PI/180\,if(eq(mod(${c}\,2)\,0)\,1\,-1)*${ANGLE_RANDOMNESS}*PI/180):ow=$((WIDTH*4)):c=#00000000,[stream${c}collected]overlay=x=if(gt(t\,$(( (TRANSITION_DURATION+PHOTO_DURATION)*c )))\,if(lt(t\,$(( (TRANSITION_DURATION+PHOTO_DURATION)*c+TRANSITION_DURATION )))\,$((WIDTH*3/2))-w+(t-$(( c*(TRANSITION_DURATION+PHOTO_DURATION) )))/${TRANSITION_DURATION}*${WIDTH}\,(main_w-overlay_w)/2)\,-w):(main_h-overlay_h)/2"

    if [[ $((c+1)) -eq ${PHOTOS_COUNT} ]]; then
        FULL_SCRIPT+=",format=yuv420p[video]\""
    else
        FULL_SCRIPT+="[stream$((c+1))collected];"
    fi
done

# 7. END
FULL_SCRIPT+=" -map [video] -vsync 2 -async 1 -rc-lookahead 0 -g 0 -profile:v main -level 42 -c:v libx264 -r ${FPS} ../advanced_photo_collection.mp4"

eval ${FULL_SCRIPT}

ELAPSED_TIME=$(($SECONDS - $START_TIME))

echo -e '\nSlideshow created in '$ELAPSED_TIME' seconds\n'

unset $IFS