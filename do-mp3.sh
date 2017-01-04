#!/bin/bash

#set -e # set -o errexit

#todo
# cleanup
# choose preset: voice, music

# Conversion steps
# RAW_WAV -> MAKE MONO -> DETECT SILENCE -> CALCULATE TRACKS
#                                        -> READ TRACKS FROM FILE

if [ $# -ne 1 ]; then
	echo "Usage: $0 PATH"
	exit -1
fi

BASE_DIR=$(dirname "$0")

# 101 = 'Speech'
ID3_TAG=101
ID3_TITLE="Church 'Around Christ'"
ID3_IMAGE="$BASE_DIR/logo.jpg"

TMP_FILE=""

echo "basedir       = $BASE_DIR"
echo "currdir       = $PWD"

trap cleanup INT TERM EXIT

function cleanup() {
	echo "TODO: Cleanup..."
	exit
}

function handle_raw_wav_file() {

	FILE_PATH="$1"
	FILE_DIR=$(dirname "$1")
	FILE_NAME_EX="${FILE_PATH##*/}"
	FILE_EX=$([[ "$FILE_NAME_EX" = *.*  ]] && echo ".${FILE_NAME_EX##*.}" || echo '')
	FILE_NAME_ONLY="${FILE_NAME_EX%.*}"
	LABELS_PATH="$FILE_DIR/$FILE_NAME_ONLY.txt"
	TRIM_PATH="$FILE_DIR/$FILE_NAME_ONLY-trim$FILE_EX"
	TARGET_DIR="$FILE_DIR/$FILE_NAME_ONLY"

	echo ""
	echo "file dir      = $FILE_DIR"
	echo "file name+ext = $FILE_NAME_EX"
	echo "file ext      = $FILE_EX"
	echo "file name     = $FILE_NAME_ONLY"
	echo "labels file   = $LABELS_PATH"
	echo "trim file     = $TRIM_PATH"
	echo "target dir    = $TARGET_DIR"
	echo ""

	if [ ! `echo $FILE_EX | grep -i ".wav"`  ]; then
		echo "Expected WAV input file."
		exit $?
	fi

	if [ -f "$LABELS_PATH" ]; then
		OLDIFS=$IFS
		IFS='	'
		while read startTime endTime labelName
		do
			echo ""
			echo "Start Time : $startTime"
			echo "End Time : $endTime"
			echo "Label : $labelName"
			echo "Duration : `echo $endTime-$startTime | bc`"

			if [ ! -z $labelName ]; then
				sox "$FILE_PATH" "$TRIM_PATH" trim $startTime `echo $endTime-$startTime | bc`
				compress_wav_to_mp3 "$TRIM_PATH" "$TARGET_DIR/$FILE_NAME_ONLY-$labelName.mp3" "$labelName"
				rm -rf "$TRIM_PATH"
			fi
		done < "$LABELS_PATH"
		IFS=$OLDIFS
	else
		compress_wav_to_mp3 "$FILE_PATH" "$TARGET_DIR/$FILE_NAME_ONLY.mp3" "$FILE_NAME_ONLY"
	fi
}

function compress_wav_to_mp3() {
	input_file=$1
	output_file=$2
	label_name=$3

	output_dir=$(dirname "$output_file")
	if [ ! -d "$output_dir" ]; then
		mkdir "$output_dir"
	fi

	echo "Choose MP3 preset for '$label_name':"
	echo "   (0) ignore"
	echo "   (1) voice"
	echo "   (2) music"
	read choise </dev/tty

	if [ $choise = "1" ]; then
		make_voice_mp3 "$input_file" "$output_file"
	fi
	if [ $choise = "2" ]; then
		make_music_mp3 "$input_file" "$output_file"
	fi
}

function make_voice_mp3() {
	in_file=$1
	out_file=$2

	DRC=24
	LIMIT=6
	
	#compand 0.3,1 6:-70,-60,-20 -5 -90 0.2 
	echo ""
	echo "Making voice track..."
	echo ""
	sox "$in_file" -t wav - \
		--show-progress \
		remix - \
		highpass 100 \
		norm \
		compand 0.3,1 6:-70,-60,-$DRC -$LIMIT -90 0.2 \
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
		"$out_file"
		#lame -V 8 --vbr-new -h -q 0

	return ${PIPESTATUS[0]} || ${PIPESTATUS[1]}
}

function make_music_mp3() {
	in_file=$1
	out_file=$2
	
	echo ""
	echo "Making music track..."
	echo ""
	sox "$in_file" -t wav - \
		--show-progress \
		compand 0.1,0.3 -90,-90,-70,-58,-55,-43,-31,-31,-21,-21,0,-20 0 0 0.1 \
		gain -n \
	| \
	lame --preset insane -q 0 \
		--tl "$ID3_TITLE" \
		--tg "$ID3_TAG" \
		--ti "$ID3_IMAGE" \
		- \
		"$out_file"
	return ${PIPESTATUS[0]} || ${PIPESTATUS[1]}
}

if [ -f "$1" ]; then
	handle_raw_wav_file "$1"
fi

if [ -d "$1" ]; then
	  for f in "$1"*.wav; do
	    handle_raw_wav_file "$f"
	  done
fi

exit