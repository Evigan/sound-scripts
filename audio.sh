#!/bin/bash

MY_DIR=$(dirname "$0")
ID3_TAG_SPEECH=101
ID3_TITLE="Church 'Around Christ'"
ID3_IMAGE="$MY_DIR/logo.jpg"
LIUM_JAR="$MY_DIR/LIUM_SpkDiarization-8.4.1.jar"

function mp3() {
	# filedir=$(dirname "$1")
	# filename=$(basename "$1")
	# extension="${filename##*.}"
	# filename="${filename%.*}"

	output=$1.mp3
	shift
	lame $* --tl "$ID3_TITLE" --tg "$ID3_TAG_SPEECH" --ti "$ID3_IMAGE" - "$output"
}

function mp4() {
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

function echo_time_taken() {	
	echo "   ---"
	echo "   --- Time taken: $((($(date +%s)-$1)/60)) minute(s)"
	echo "   ---"
}

function split_sox() {
	local seconds=${2:-4.0}
	echo "Silence detection=$seconds second(s)"	
	sox -V3 "$1" "$1-p.${1##*.}" silence 1 0.1 1% 1 $seconds 1% : newfile : restart
}

function split_lium() {	
	
	local mono_file="$1-mono.wav"
	local lium_file="$mono_file.seg"
	
	mono16k "$1" "$mono_file"
	
	lium "$mono_file" "$lium_file"

	#convert_lium_output "$lium_file" "$mono_file"
  	
	
  	# convert_lables_file  	
}

function convert_lium_output() {

	echo "Convert LIUM output to friendly SoX input..."
	local segments_file=$1
	local audio_file=$2
	local root_dir="$segments_file-segments"

	[ -d "$root_dir" ] || mkdir "$root_dir"
	
	local count=0
	
	while read line; do
		local fields=($(echo "$line" | grep -o '[^ ]*'))

		if [ "${fields[0]}" != ";;" ]; then

			#http://www-lium.univ-lemans.fr/diarization/doku.php/diarization
			local show_name=${fields[0]}
			local channel_num=${fields[1]}
			local segment_start=${fields[2]}	# in features
			local segment_length=${fields[3]}	# in features
			local speaker_gender=${fields[4]}	# (U=unknown, F=female, M=Male)
			local type_of_band=${fields[5]}		# (T=telephone, S=studio)
			local type_of_env=${fields[6]}		# (music, speech only, …)
			local speaker_label=${fields[7]}	# Speaker id 

			local speaker=${speaker_label}-${speaker_gender}
            local seg_start_time=$(echo "scale=2; ${segment_start} / 100" | bc)
            local seg_length_time=$(echo "scale=2; ${segment_length} / 100" | bc)
            local seg_end_time=$(echo "scale=2; (${segment_start} + ${segment_length}) / 100" | bc)

            local segment_info="$speaker; start=$seg_start_time; len=$seg_length_time; end=$seg_end_time"
            echo $segment_info
            echo $segment_info >> $audio_file.txt

            # [ -d "$speaker_dir" ] || mkdir "$speaker_dir"
            # local c=$(printf "%04d" $count)
            # sox -q "$audio_file" "$speaker_dir/$speaker_gender-$c.wav" trim $start_time $duration_time
            ((++count))
		fi		
	done < "$segments_file"	
}

function merge_wavs() {	
	sox $(for f in "$1"/*.wav; do echo -n "$f "; done) $(basename $1).wav
}

function mono() {
	echo "Resampling $1 to 16kHz, 1 channel, 16 bit ${1##*.}."
	
	local begin=$(date +%s)
	local infile=$1
	local outfile=${2:-${1%.*}-mono}.${1##*.}

	echo "Output file : "$outfile""

	sox "$infile" -b 16 "$outfile" \
		--show-progress \
		remix - \
		highpass 100 \
		norm \
		compand 0.05,0.2 6:-54,-90,-36,-36,-24,-24,0,-12 0 -90 0.1 \
		rate -v 16k

	echo_time_taken $begin
}

function lium() {
	echo "Starting LIUM Speech Diarization process ..."	

	local begin=$(date +%s)
	local infile=$1
	local outfile=${2:-${1%.*}-lium}.seg

	java -Xmx2024m -jar "$LIUM_JAR" \
  		--fInputMask="$infile" \
  		--sOutputMask="$outfile" \
  		--doCEClustering $(basename "$infile")

  	soxi "$infile"
  	echo_time_taken $begin
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

"$@"