#!/usr/bin/env bash

# Author: "Philipp Moers" <soziflip@gmail.com>

set -e
set -o pipefail

set -m # enable job control (e.g. `fg` command)


[ "${BASH_VERSINFO:-0}" -ge 4 ] || (echo "Bash version >= 4 required, sorry." && exit 1)

SCRIPTNAME=$(basename "$0")

function _print_help_msg() {
    cat <<-EOF
$SCRIPTNAME - play some web radio

SYNOPSIS

    $SCRIPTNAME [OPTIONS] [QUERY|URL]

DESCRIPTION

    $SCRIPTNAME is a small script to conveniently play some web radio, e.g. on a Raspberry Pi.

NOTE

    Either provide a query to search for saved radio stations or provide a web radio URL.
    If a URL is provided, it will start playing immmediately.
    If the query matches exactly one station, it will pick it and start playing immmediately.
    If the query matches more than one station, you can pick a station interactively.

OPTIONS

    --list | -l                     List available radio stations (hardcoded in this script).

    --detach | -i                   Start in the background.

    --kill | -k                     Stop any radio that was started in the background.

    --status | -s                   Print information about currently played station.

    --volume | -v [[+-]<num>]       Set (or get) audio volume. (get has a known bug)

    --non-interactive | -n          If query matches more than one station, exit with failure.

    --help | -h                     Print this help message.

EOF
}


function require() {
    if ! (command -v "$1" >/dev/null); then
        echo "ERROR: Command $1 required. Please install the corresponding package!"
        exit 1
    fi
}

require vlc
require lsof
require nc


declare -A RADIO_STATION_LIST
RADIO_STATION_LIST["Brainradio Klassik"]="http://brainradioklassik.stream.laut.fm/brainradioklassik"
RADIO_STATION_LIST["Radio Swiss Jazz"]="http://www.radioswissjazz.ch/live/mp3.m3u"
RADIO_STATION_LIST["Soul Radio"]="http://soulradio02.live-streams.nl:80/live"
RADIO_STATION_LIST["fip Radio"]="http://direct.fipradio.fr/live/fip-midfi.mp3"


# ALSA audio device to use (list with `aplay -L`)
# If device not found, this will be ignored and default device will be used.
ALSA_DEVICE="${ALSA_DEVICE:-plughw:CARD=sndrpihifiberry,DEV=0}"

VLC_GAIN=0.3

VLC_RC_HOST=localhost
VLC_RC_PORT=9592 # hardcoded because using lsof (_find_unused_port) may be problematic

STATEDIR=/tmp/radiopi
PIDFILE="$STATEDIR/vlc.pid"
PORTFILE="$STATEDIR/vlc.port"
VOLUMEFILE="$STATEDIR/vlc.volume"
STATUSFILE="$STATEDIR/status.txt"


function _find_unused_port() {
    for PORT in {9555..9999}; do
        if ! lsof -i :"$PORT" >/dev/null; then
            break
        fi
    done
    echo "$PORT"
}

function _wait_until_tcp_port_open() {
    local HOST="$1"
    local PORT="$2"
    local SLEEP="0.02"
    while ! nc -z "$HOST" "$PORT"; do
        sleep "$SLEEP"
    done
}

function _is_playing() {
    if [[ -f "$PIDFILE" ]]; then
        PID=$(cat $PIDFILE)
        if ps "$PID" >/dev/null; then
            return 0
        fi
        return 1
    else
        return 1
    fi
}

function _get_running_radio_port() {
    PORT=$(cat "$PORTFILE")
    if [[ -z "$PORT" ]]; then
        echo "ERROR: Can't find portfile $PORTFILE!"
        exit 1
    fi
    echo "$PORT"
}

function _test_audio_stream_url() {
    local URL="$1"
    # unfortunately doesn't work for some stations
    STATION_WHITELIST=(
        "${RADIO_STATION_LIST["Radio Swiss Jazz"]}"
        "${RADIO_STATION_LIST["fip Radio"]}"
    )
    # 'array contains'
    if printf '%s\n' "${STATION_WHITELIST[@]}" | grep -q -P "^$URL$"; then
        return 0
    fi
    CONTENT_TYPE=$(timeout 3s curl -sI -f -o /dev/null -w '%{content_type}\n' "$URL")
    if [[ "$CONTENT_TYPE" =~ ^audio/ ]]; then
        return 0
    else
        return 1
    fi
}

function _configure_vlc_netcat_cmd() {
    if [[ -z "$VLC_NETCAT_CMD" ]]; then
        local NETCAT_HELP_OUTPUT
        local VLC_RC_PORT
        VLC_RC_PORT=$(_get_running_radio_port)
        NETCAT_HELP_OUTPUT=$(nc -h 2>&1)
        if grep -q '^GNU netcat' <(echo "$NETCAT_HELP_OUTPUT" | head -n 1); then
            VLC_NETCAT_CMD="nc -c $VLC_RC_HOST $VLC_RC_PORT"
        elif grep -q '^OpenBSD netcat' <(echo "$NETCAT_HELP_OUTPUT" | head -n 1); then
            VLC_NETCAT_CMD="nc -N $VLC_RC_HOST $VLC_RC_PORT"
        else
            echo 'ERROR: Unknown netcat version!'
            exit 1
        fi
    fi
}

# TODO: debug.
# `echo volume | nc -c localhost 9555` doesn't output anything, but interactively it works
function _get_vlc_volume() {
    _configure_vlc_netcat_cmd
    echo "volume" | $VLC_NETCAT_CMD
    echo "$VOLUME"
}

function _set_vlc_volume() {
    local VOLUME="$1"
    if [[ ! "$VOLUME" =~ ^[+-]?[0-9]+$ ]]; then
        echo "ERROR: Invalid volume $VOLUME"
        exit 1
    fi
    _configure_vlc_netcat_cmd
    echo "volume $VOLUME" | $VLC_NETCAT_CMD
    # TODO: uncomment as soon as _get_vlc_volume is debugged:
    # ABSOLUTE_VOLUME=$(_get_vlc_volume)
    # echo "$ABSOLUTE_VOLUME" > "$VOLUMEFILE"
    # echo "Set VLC volume to $ABSOLUTE_VOLUME"
    echo "$VOLUME" > "$VOLUMEFILE"
    echo "Set VLC volume ($VOLUME)"
}

function _list_stations() {
    for STATION in "${!RADIO_STATION_LIST[@]}"; do
        echo $STATION
    done
}

function _pick_station_interactively() {
    local QUERY_PREFILL="$1"
    require fzf
    _list_stations | fzf -q "$QUERY_PREFILL"
}

function _start_playback() {
    local TITLE="$1"
    local AUDIO_SRC="$2"
    # local VLC_RC_PORT
    if ! _test_audio_stream_url "$AUDIO_SRC"; then
        echo "ERROR: $AUDIO_SRC does not look like an audio source."
        exit 2
    fi
    # VLC_RC_PORT=$(_find_unused_port) # using lsof may be problematic (e.g. for webserver users)
    echo "$VLC_RC_PORT" > "$PORTFILE"
    if aplay -L | grep -q "$ALSA_DEVICE"; then
        # echo "Using device $ALSA_DEVICE"
        VLC_OUTPUT_ARGS=(--aout=alsa --alsa-audio-device="$ALSA_DEVICE")
    fi
    VLC_ARGS=(
        "${VLC_OUTPUT_ARGS[@]}" \
        --gain="$VLC_GAIN" \
        --volume-step=1 \
        # --no-volume-save
        -I rc --rc-host="$VLC_RC_HOST:$VLC_RC_PORT" \
        "$AUDIO_SRC"
    )
    echo "Currently playing $TITLE..." > "$STATUSFILE"
    vlc "${VLC_ARGS[@]}" & echo $! > $PIDFILE
    if [[ -n "$VOLUME" ]]; then
        _wait_until_tcp_port_open "$VLC_RC_HOST" "$VLC_RC_PORT"
        _set_vlc_volume "$VOLUME"
    fi
    VOLUME=$(_get_vlc_volume)
    echo "$VOLUME" > "$VOLUMEFILE"
    if [[ -z "$DETACH" ]]; then
        fg # play until interrupt
        _cleanup_after_playback
    fi
}

function _stop_playback() {
    if [[ ! -f $PIDFILE ]]; then
        echo "WARNING: Did not find PID file $PIDFILE"
    else
        PID=$(cat $PIDFILE)
        if ps "$PID" >/dev/null; then
            echo "Killing process with PID $PID"
            kill "$PID" && rm $PIDFILE
        else
            echo "WARNING: No process found with PID $PID"
            rm "$PIDFILE"
        fi
    fi
    _cleanup_after_playback
}

function _cleanup_after_playback() {
    if [[ -f "$STATUSFILE" ]]; then
        rm "$STATUSFILE"
    fi
}

function _print_status_msg() {
    if [[ -f "$STATUSFILE" ]]; then
        cat "$STATUSFILE"
    else
        echo "Nothing playing."
        exit 1
    fi
}

function _main() {
    local QUERY_OR_URL="$1"
    if [[ -n "$QUERY_OR_URL" ]] && _test_audio_stream_url "$QUERY_OR_URL"; then
        AUDIO_SRC="$QUERY_OR_URL"
        TITLE="$AUDIO_SRC"
    elif [[ -n "$QUERY_OR_URL" && -n "${RADIO_STATION_LIST[$QUERY_OR_URL]}" ]]; then
        AUDIO_SRC="${RADIO_STATION_LIST[$QUERY_OR_URL]}"
        TITLE="$QUERY_OR_URL"
    elif [[ -n "$NON_INTERACTIVE" ]]; then
        echo "ERROR: Station not found"
        exit 1
    else
        STATION=$(_pick_station_interactively "$QUERY_OR_URL")
        if [[ -z "$STATION" ]]; then
            echo "No station selected."
            exit 1
        else
            AUDIO_SRC="${RADIO_STATION_LIST[$STATION]}"
            TITLE="$STATION"
        fi
    fi
    _start_playback "$TITLE" "$AUDIO_SRC"
}


mkdir -p "$STATEDIR"

while [[ $# -gt 0 ]]; do
    ARG="$1"
    case $ARG in
        --help|-h)
            _print_help_msg;
            exit 0
            ;;
        --list|-l)
            _list_stations;
            exit 0
            ;;
        --non-interactive|-n)
            NON_INTERACTIVE=1;
            shift
            ;;
        --detach|-d)
            DETACH=1;
            shift
            ;;
        --status|-s)
            _print_status_msg;
            exit 0
            ;;
        --kill|-k)
            _stop_playback;
            exit 0
            ;;
        --volume|-v)
            VOLUME="$2"
            shift
            if _is_playing; then
                if [[ -z "$VOLUME" ]]; then
                    cat "$VOLUMEFILE"
                else
                    shift
                    _set_vlc_volume "$VOLUME"
                fi
                exit 0
            else
                if [[ -n "$VOLUME" ]]; then
                    shift
                fi
            fi
            ;;
        *)
            QUERY_OR_URL=$ARG
            shift
            ;;
    esac
done


_main "$QUERY_OR_URL"
