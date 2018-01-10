#!/bin/bash
########################################################
#  INSTALL (Ubuntu)
########################################################
function is_installed() {
	[[ -z $(dpkg --get-selections | grep "$1") ]] && return $(false) || return $(true)
}

function do_install() {
     if ! is_installed "$1"; then sudo apt-get -y install "$1"; fi
}

function install_multimedia_repo() {
    if [[ -z $(grep -r "mc3man/trusty-media" /etc/apt/sources.list.d) ]]; then
        echo Adding multimedia repo...
        sudo add-apt-repository -y ppa:mc3man/trusty-media
        sudo apt-get -y update
        sudo apt-get -y dist-upgrade
        echo Adding multimedia repo...done
    fi
}

function install_all()
{
    #install_multimedia_repo
    do_install sox     #SoX - Sound eXchange (http://sox.sourceforge.net/)
    do_install lame    #LAME MP3 Encoder (http://lame.sourceforge.net/)
    do_install ffmpeg  #FFmpeg - cross-platform solution to record, convert and stream audio and video (https://ffmpeg.org/)
                    #FFmpeg is currently used only for silence detenction. SoX can also detect silence but doesn't provide any info =(
}
########################################################

function make_clean_voice() {
    # This script, as used at http://language101.com, shows using several
    # effects in combination to normalise and trim voice recordings that
    # may have been recorded using different microphones, with differing
    # background noise etc.
    
    sox "$1" "$2" -S \
        remix - \
        highpass 100 \
        norm \
#        compand 0.3,5 6:-70,-60,-20 -10 -6 0.2 fade 1 \
        compand 0.05,0.2 6:-54,-90,-36,-36,-24,-24,0,-12 0 -90 0.1 \
#                 |   |  |  |   |   |                    |  |   |
#                 |   |  |  |   |   |                    |  |   |
#                 |   |  |  |   |   |                    |  |   |
#                 |   |  |  |   |   |                    |  |   Initial sample time
#                 |   |  |  |   |   |                    |  Expected initial level
#                 |   |  |  |   |   |                    Overall output gain to avoid clipping
#                 |   |  |  |   |   Output range from zero to this number
#                 |   |  |  |   Input range from 0 to this number
#                 |   |  |  Ignore companding below this level
#                 |   |  Soft knee companding
#                 |   Decay time is long to prevent rising noise in pauses
#                 Attack time is fast to quiet loud music bumpers
        vad -T 0.6 -p 0.2 -t 5 \
        fade 0.1 \
        reverse \
        vad -T 0.6 -p 0.2 -t 5 \
        fade 0.1 \
        reverse \
        norm -0.5 \
        rate -v 22050
}

########################################################

install_all
echo OK
