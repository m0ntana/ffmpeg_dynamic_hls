#!/bin/bash

cd $(dirname $0)
. config.sh

VIDEOWH="${VIDEOW}x${VIDEOH}"

function read_segment() {
    ffmpeg -hide_banner -err_detect ignore_err -y \
    -ss $OFFSET -fflags +genpts -i "$INPUT" \
    -dn -sn \
    -filter_complex \
    "[0:v]scale=${VIDEOW}:${VIDEOH}:force_original_aspect_ratio=decrease,pad=${VIDEOW}:${VIDEOH}:\(ow-iw\)/2:\(oh-ih\)/2,setsar=1,fps[vout]" \
    -filter_complex \
     "[0:a]pan=stereo|FL=FC+0.30*FL+0.30*BL|FR=FC+0.30*FR+0.30*BR,
      loudnorm=I=-16:TP=-1.5:LRA=11,
      dynaudnorm=p=1/sqrt(2):m=100:s=12:g=15[aout]" \
    -c:v libx264 -preset ultrafast -tune film -x264-params keyint=60:min-keyint=2 -pix_fmt yuv420p \
    -c:a aac -ar 44100 -sample_fmt fltp \
    -t $LENGTH \
    -map [vout] -map [aout] \
    -copyinkf:[vout] \
    -f mpegts -output_ts_offset $OFFSET \
    -
}

function get_file_info() {
    tmpinfo=$(ffprobe -hide_banner -loglevel warning -of flat=s=_ -show_format "$INPUT")
    eval $tmpinfo
}

function get_params() {
    ENCODED=$(echo $REQUEST_URI | cut -d '/' -f 3)
    OFFSET=$(echo $REQUEST_URI | cut -d '/' -f 4)
    LENGTH=$(echo $REQUEST_URI | cut -d '/' -f 5)
    INPUT="${MEDIA_DIR}/$(echo $ENCODED | basenc --base64url -d)"
}

echo -ne "${HEADER_MPEGTS}\n\n"

get_params
read_segment
