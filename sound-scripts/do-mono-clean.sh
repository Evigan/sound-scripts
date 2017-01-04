#!/bin/bash

# This script, as used at http://language101.com, shows using several
# effects in combination to normalise and trim voice recordings that
# may have been recorded using different microphones, with differing
# background noise etc.

if [ $# -lt 2 ]; then
  echo "Usage: $0 infile outfile"
  exit 1
fi

sox "$1" "$2" -S \
  remix - \
  highpass 100 \
  norm \
  compand 0.05,0.2 6:-54,-90,-36,-36,-24,-24,0,-12 0 -90 0.1 \
  vad -T 0.6 -p 0.2 -t 5 \
  fade 0.1 \
  reverse \
  vad -T 0.6 -p 0.2 -t 5 \
  fade 0.1 \
  reverse \
  norm -0.5 \
  rate -v 22050