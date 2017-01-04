#!/bin/bash

if [ $# -ne 1 ]; then
	echo "Usage: $0 PATH"
	exit -1
fi

function make_tracks() {

	SILENCE_SEC=2
	SILENCE_SEC_LESS=$(echo ""$SILENCE_SEC" * .9" | bc)

	FILE_PATH="$1"
	FILE_DIR=$(dirname "$1")
	FILE_NAME_EX="${FILE_PATH##*/}"
	FILE_EX=$([[ "$FILE_NAME_EX" = *.*  ]] && echo ".${FILE_NAME_EX##*.}" || echo '')
	FILE_NAME_ONLY="${FILE_NAME_EX%.*}"
	TRACKS_FILE_PATH="$FILE_DIR/$FILE_NAME_ONLY.txt"

	echo ""
	echo "file dir      = $FILE_DIR"
	echo "file name+ext = $FILE_NAME_EX"
	echo "file ext      = $FILE_EX"
	echo "file name     = $FILE_NAME_ONLY"
	echo "tracks file   = $TRACKS_FILE_PATH"
	echo ""

	if [ ! `echo $FILE_EX | grep -i ".wav"`  ]; then
		echo "Expected WAV input file."
		exit $?
	fi

	silence_ranges=($(ffmpeg -i "$FILE_PATH" -af silencedetect=noise=-48dB:d=$SILENCE_SEC -f null - 2>&1 | grep -Eo 'silence_start: (\d+.\d+)|silence_end: (\d+.\d+)' | cut -d ' ' -f 2))
	tracks_ranges=()

	echo ""
	echo "Silence gaps: ${silence_ranges[*]}"
	echo ""

	if [ $(echo ${#silence_ranges[@]} % 2 | bc) -ne 0 ]; then
		echo "ERROR: Expected even number of silence gaps"
		exit -1
	fi

	silence_start=""
	silence_end=""

	echo "Caclulating tracks candidates..."

	for i in "${silence_ranges[@]}"
	do
		if [ -z "$silence_start" ]
		then
			silence_start="$i"
		else
			if [ -z "$silence_end" ]
			then
				silence_end="$i"
			fi
		fi

		if [ "$silence_start" != "" ] && [ "$silence_end" != "" ]; then

			if [ ${#tracks_ranges[@]} -eq 0 ]; then
				if [ $(echo ""$silence_start" == 0" | bc) -eq 1 ]; then
					tracks_ranges+=("$silence_end")
				else
					tracks_ranges+=("0.0000")			#add first track start
					tracks_ranges+=("$silence_start")	#add first track end
					tracks_ranges+=("$silence_end")		#add next track start
				fi
			else
				tracks_ranges+=("$silence_start")		#add current track end
				tracks_ranges+=("$silence_end")			#add next track start
			fi
			
			silence_start=""
			silence_end=""
		fi
	done

	tracks_ranges+=($(soxi -D "$FILE_PATH")) #add last track end point (soxi will read it from file header info)

	echo ""
	echo "----------------"
	echo "TRACK CANDIDATES"
	echo "----------------"
	print_ranges tracks_ranges[@]

	track_name=""
	track_start=""
	track_end=""
	track_duration=""
	tracks=()

	for i in "${tracks_ranges[@]}"
	do
		if [ -z "$track_start" ]; then
			track_start="$i"
		else
			if [ -z "$track_end" ]; then
				track_end="$i"
			fi
		fi
		if [ "$track_start" != "" ] && [ "$track_end" != "" ]; then
			track_duration=$(echo $track_end - $track_start | bc)

			if [ $(echo ""$track_duration" > "$SILENCE_SEC_LESS"" | bc) -eq 1  ]; then

				echo "\nPlaying "$CYAN""$track_duration""$NO_COLOR" starting from $track_start ..."

				sox -q "$FILE_PATH" -t wav - trim "$track_start" "$track_duration" | play - vol 0.99

				if [ "$track_name" != "" ]; then
					echo "Is this continue of '"$track_name"'? [y/n]:\c"
					read yes
					if [ "$yes" == "y" ]; then
						tracks[${#tracks[@]}-1]="$track_end"
					else
						track_name=""
					fi
				fi

				if [ -z "$track_name" ]; then
					echo ""
					echo "Enter track name and press [ENTER]: \c"

					read entered_name
					if [ "$entered_name" != "" ]; then
						track_name="$entered_name"
						echo "Adding track "$track_name""
						tracks+=("$track_name")
						tracks+=("$track_start")
						tracks+=("$track_end")
					else
						echo_cyan "Skiping \c"
						print_one_range_line "$track_start" "$track_end"
					fi
				fi
			else
				echo_cyan "Skiping small \c"
				print_one_range_line "$track_start" "$track_end"
			fi

			track_start=""
			track_end=""
		fi
	done

	echo ""
	echo "Tracks: ${tracks[*]}"
	echo ""

	echo "Would you like to save tracks now? [y/n]: \c"
	read yes
	if [ "$yes" == "y" ]; then

		if [ -f "$TRACKS_FILE_PATH" ]; then
			echo "Tracks file "$TRACKS_FILE_PATH" already exists. Whould you like to override? [y/n]:\c"

			read yes

			if [ "$yes" == "y" ]; then
				rm "$TRACKS_FILE_PATH"
			else
				exit -1
			fi
		fi

		track_name=""
		track_start=""
		track_end=""

		for i in "${tracks[@]}"
		do
			if [ -z "$track_name" ]; then
				track_name="$i"
			else
				if [ -z "$track_start" ]; then
					track_start="$i"
				else
					if [ -z "$track_end" ]; then
						track_end="$i"
					fi
				fi
			fi

			if [ "$track_name" != "" ] && [ "$track_start" != "" ] && [ "$track_end" != "" ]; then
				echo ""$track_start"\t"$track_end"\t"$track_name"" >> "$TRACKS_FILE_PATH"
				track_name=""
				track_start=""
				track_end=""
			fi
		done

		echo ""
		echo_cyan "All tracks information saved to "$TRACKS_FILE_PATH""
		echo ""
		echo "$(cat "$TRACKS_FILE_PATH")"
	fi

	exit 0
}

function print_ranges() {
	declare -a RANGES=("${!1}")
	local tstart=""
	local tend=""
	
	echo "Total ranges count = $(echo ${#RANGES[@]} / 2 | bc)"

	for i in "${RANGES[@]}"
		do
			if [ -z "$tstart" ]
			then
				tstart="$i"
			 else
				if [ -z "$tend" ]
				then
					tend="$i"
				fi
			fi

			if [ "$tstart" != "" ] && [ "$tend" != "" ]; then
				print_one_range_line "$tstart" "$tend"
				tstart=""
				tend=""
			fi
	done

	if [ "$tstart" != "" ] || [ "$tend" != "" ]; then
		print_one_range_line "$tstart" "$tend"
	fi
}

function print_one_range_line() {
	local duration=$(echo $2 - $1 | bc)
	local line="range(seconds): start = "$1"  \tend = "$2"  \tduration = "$duration"  \t($(echo "scale=1;("$duration") / 60" | bc) min)"$NO_COLOR""
	[[ $(echo ""$duration" <= "$SILENCE_SEC_LESS"" | bc) -eq 1  ]] && echo_red "$line" || echo "$line"
}

RED="\x1B[1;31m"
CYAN="\x1B[1;36m"
NO_COLOR="\x1B[0m"

function echo_color() {
	echo ""$1""$2""$NO_COLOR""
}

function echo_red() {
	echo_color "$RED" "$1"
}

function echo_cyan() {
	echo_color "$CYAN" "$1"
}

if [ -f "$1" ]; then
	make_tracks "$1"
fi
