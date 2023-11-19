#!/bin/bash

cd $(dirname $0)
. config.sh

function find_media() {
    find ${MEDIA_DIR} \
    -ipath "*telegram*desktop*" -prune \
    -o -ipath "*whatsapp*" -prune \
    -o \( -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.ts" \) -type f \
    -printf "$PFORMAT"
}

function find_media_by_time() {
    PFORMAT="%T+;%P\n"
    find_media | sort -r | cut -d ';' -f 2
}

function find_media_by_name() {
    PFORMAT="%P\n"
    find_media | sort -r
}

function playlist_item() {
    short=$1
    encoded=$2
    
    echo "#EXTINF:0, ${short}"
    echo "/f/${encoded}/p.m3u8"
}

function playlist() {
    echo "#EXTM3U"
    
    fptr=$1
    IFS=$'\n'
    for line in $($fptr); do
	short=$(basename "$line")
	encoded=$(echo -ne "$line" | basenc -w0 --base64url)
	playlist_item "$short" "$encoded"
    done;
}

echo -ne "$HEADER_PLAYLIST\n\n"

sortby=$(echo $REQUEST_URI | awk -F '[/.]' {'print $3'})

case $sortby in
    "t")
	playlist "find_media_by_time"
	;;
    "n")
	playlist "find_media_by_name"
	;;
    "*")
	exit 0
	;;
esac
