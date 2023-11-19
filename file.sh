#!/bin/bash

cd $(dirname $0)
. config.sh

function get_file_info() {
    tmpinfo=$(ffprobe -hide_banner -loglevel warning -of flat=s=_ -show_format "$INPUT")
    eval $tmpinfo
}

function generate_segments() {
    offset=0
    
    while [ "$offset" -lt "${format_duration}" ]; do
	echo "#EXTINF:$SEGMENT_LENGTH,"
	echo "${REQUEST_SCHEME}://${HTTP_HOST}/s/${ENCODED}/$offset/$SEGMENT_LENGTH/s.ts"
	offset=$(( $offset + $SEGMENT_LENGTH ))
    done;
    
    LENGTH=${format_duration}
}

function playlist() {
cat <<EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-ALLOW-CACHE:YES
#EXT-X-TARGETDURATION:$SEGMENT_LENGTH
#EXT-X-MEDIA-SEQUENCE:0
EOF

    generate_segments
    echo "#EXT-X-ENDLIST"
}

echo -ne "${HEADER_PLAYLIST}\n\n"

ENCODED=$(echo $REQUEST_URI | cut -d '/' -f 3)
INPUT="${MEDIA_DIR}/$(echo $ENCODED | basenc --base64url -d)"

# get info about media file
get_file_info

# convert float to int
format_duration=${format_duration%.*}

# generate playlist
playlist
