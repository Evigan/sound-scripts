#!/bin/sh

MY_DIR=$(dirname "$0")
ID3_TAG_SPEECH=101
ID3_TITLE="Church 'Around Christ'"
ID3_IMAGE="$MY_DIR/logo.png"

function voice() {

	filedir=$(dirname "$1")
	filename=$(basename "$1")
	extension="${filename##*.}"
	filename="${filename%.*}"

	# sox "$1" -t $extension - --show-progress \
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
	| \
	lame --preset cbr 48 -q 0 \
		--tl "$ID3_TITLE" \
		--tg "$ID3_TAG" \
		--ti "$ID3_IMAGE" \
	    - \
		"$filedir/$filename.mp3"
	#lame -V 8 --vbr-new -h -q 0
}

function music() {

	filedir=$(dirname "$1")
	filename=$(basename "$1")
	extension="${filename##*.}"
	filename="${filename%.*}"

	sox "$@" -t wav - --show-progress \
		compand 0.1,0.3 -90,-90,-70,-58,-55,-43,-31,-31,-21,-21,0,-20 0 0 0.1 \
		gain -n \
	| \
	lame --preset insane -q 0 \
		--tl "$ID3_TITLE" \
		--tg "$ID3_TAG" \
		--ti "$ID3_IMAGE" \
	    - \
		"$filedir/$filename.mp3"
}

function slice() {

	SEC=${2:-4.0}
	echo "SILENCE DELAY=$SEC seconds"
	sox -V3 "$1" "$1_p.${1##*.}" silence 1 0.1 1% 1 $SEC 1% : newfile : restart
}

"$@"