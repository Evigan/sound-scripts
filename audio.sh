#!/bin/sh

MY_DIR=$(dirname "$0")
ID3_TAG_SPEECH=101
ID3_TITLE="Church 'Around Christ'"
ID3_IMAGE="$MY_DIR/logo.png"

function mp3() {
	# filedir=$(dirname "$1")
	# filename=$(basename "$1")
	# extension="${filename##*.}"
	# filename="${filename%.*}"

	output=$1.mp3
	shift
	lame $* --tl "$ID3_TITLE" --tg "$ID3_TAG_SPEECH" --ti "$ID3_IMAGE" - "$output"
}

function slice() {
	SEC=${2:-4.0}
	echo "SILENCE DELAY=$SEC seconds"
	sox -V3 "$1" "$1-p.${1##*.}" silence 1 0.1 1% 1 $SEC 1% : newfile : restart
}

function automerge() {
	#TODO: merge parts based on RMS Peaks
	# sox -n stats
}

function voice() {
	sox "$@" -t wav - --show-progress \
		remix - \
		highpass 100 \
		norm \
		compand 0.3,1 6:-70,-60,-24 -6 -90 0.2 \
		vad -T 0.6 -p 0.2 -t 5 \
		fade 0.1 \
		reverse \
		vad -T 0.6 -p 0.2 -t 5 \
		fade 0.1 \
		reverse \
		norm -0.5 \
		rate -v 22050 \
	| mp3 "$1" --preset cbr 48 -q 0
	# | mp3 "$1" -V 8 --vbr-new -h -q 0
}

function music() {
	sox "$@" -t wav - --show-progress \
		compand 0.1,0.3 -90,-90,-70,-58,-55,-43,-31,-31,-21,-21,0,-20 0 0 0.1 \
		gain -n \
	| mp3 "$1" --preset insane -q 0
}

function youtube() {
	# https://stackoverflow.com/questions/25381086/convert-mp3-video-with-static-image-ffmpeg-libav-bash
	ffmpeg -loop 1 \
		-i "$ID3_IMAGE" \
		-i "$1" \
		-c:v libx264 \
		-tune stillimage \
		-c:a copy \
		-shortest "$1".mp4
	# ffmpeg -loop 1 -i "$ID3_IMAGE" -i "$1" -c:a aac -ab 112k -c:v libx264 -shortest -strict -2 "$1".mp4
}

"$@"