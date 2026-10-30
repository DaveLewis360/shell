#!/bin/sh
# video-native.sh SRC DST WIDTH HEIGHT FPS
#
# Makes the copy of a video wallpaper that the background plays: H.264 (yuv420p, no
# audio), scaled down until it just covers WIDTH x HEIGHT (never scaled up) and capped
# at FPS. A 4K original costs the decoder about four times as much as the screen can
# show. The original is only read. ffmpeg writes next to DST, the data is flushed and
# the file renamed into place, so a reader never sees half a video, not even after a
# power loss. Exits 0 when DST exists.
src=$1 dst=$2 w=$3 h=$4 fps=$5
[ -s "$dst" ] && exit 0
tmp="${dst%.*}.part"
# The side that limits the cover gets the screen's size (or its own, if smaller); the
# other one follows the aspect ratio
scale="scale=w='if(gt(iw*$h\,ih*$w)\,-2\,min(iw\,$w))':h='if(gt(iw*$h\,ih*$w)\,min(ih\,$h)\,-2)'"
ffmpeg -nostdin -hide_banner -loglevel error -y -threads 4 -i "$src" \
    -map 0:v:0 -an -sn -dn -vf "$scale" -fpsmax "$fps" \
    -c:v libx264 -preset veryfast -crf 22 -profile:v high -pix_fmt yuv420p \
    -movflags +faststart -f mp4 "$tmp" && sync "$tmp" && mv -f "$tmp" "$dst"
rm -f "$tmp"
[ -s "$dst" ]
