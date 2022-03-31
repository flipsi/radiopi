#!/usr/bin/env bash

# Author: "Philipp Moers" <soziflip@gmail.com>

set -e
set -o pipefail
set -m # enable job control (e.g. `fg` command)

umask 000


[ "${BASH_VERSINFO:-0}" -ge 4 ] || (echo "Bash version >= 4 required, sorry." && exit 1)

DIR="$(realpath --no-symlinks "$(dirname "${BASH_SOURCE[0]}")")"
SELF=$(basename "$0")

function _print_help_msg() {
    cat <<-EOF
$SELF - play some web radio

SYNOPSIS

    $SELF [OPTIONS]       [QUERY|URL] Start radio (synchronously).
    $SELF [OPTIONS] start [QUERY|URL] Start radio (in the background).
    $SELF stop                        Stop radio.
    $SELF sleep <D>                   Stop radio in <D> minutes.
    $SELF nosleep                     Remove scheduled timer.
    $SELF status                      Print information about currently played station.
    $SELF list                        List available radio stations (hardcoded in this script).
    $SELF volume [[+-]<num>]          Set (or get) audio volume (get has a known bug).
    $SELF enable <H> <M> [<D>]        Schedule daily alarm at <Hour>:<Minute> (for <Duration> mins).
    $SELF disable                     Remove scheduled alarm.
    $SELF help                        Print this help message.

DESCRIPTION

    $SELF is a small script to conveniently play some web radio, e.g. on a Raspberry Pi.

NOTE

    Either provide a query to search for saved radio stations or provide a web radio URL.
    If a URL is provided, it will start playing immmediately.
    If the query matches exactly one station, it will pick it and start playing immmediately.
    If the query matches more than one station, you can pick a station interactively.

OPTIONS

    --non-interactive   | -n          If query matches more than one station, exit with failure.
    --random            | -r          Instead of taking query or URL, pick a random station.
    --wake-up           | -w          Start with low volume and increase over time (wakeup alarm).

EOF
}


function has() {
    local COMMAND="$1"
    command -v "$COMMAND" >/dev/null
}

function require() {
    local COMMAND="$1"
    if ! has "$COMMAND"; then
        echo "ERROR: Command $1 required. Please install the corresponding package!"
        exit 1
    fi
}


require vlc
require gawk # We want GNU awk. Raspbian apparently has the old Mawk, see https://forums.raspberrypi.com/viewtopic.php?p=178094
require lsof
require nc


declare -A RADIO_STATION_LIST
RADIO_STATION_LIST["1LIVE"]="http://wdr-1live-live.icecast.wdr.de/wdr/1live/live/mp3/128/stream.mp3"
RADIO_STATION_LIST["1LIVE DIGGI"]="http://wdr-1live-diggi.icecast.wdr.de/wdr/1live/diggi/mp3/128/stream.mp3"
RADIO_STATION_LIST["WDR 2"]="http://wdr-wdr2-rheinland.icecast.wdr.de/wdr/wdr2/rheinland/mp3/128/stream.mp3"
RADIO_STATION_LIST["WDR 3"]="http://wdr-wdr3-live.icecast.wdr.de/wdr/wdr3/live/mp3/256/stream.mp3"
RADIO_STATION_LIST["WDR 4"]="http://wdr-wdr4-live.icecast.wdr.de/wdr/wdr4/live/mp3/128/stream.mp3"
RADIO_STATION_LIST["WDR 5"]="http://wdr-wdr5-live.icecast.wdr.de/wdr/wdr5/live/mp3/128/stream.mp3"
RADIO_STATION_LIST["Die Maus"]="https://wdr-diemaus-live.icecastssl.wdr.de/wdr/diemaus/live/mp3/128/stream.mp3"
RADIO_STATION_LIST["Brainradio Klassik"]="http://brainradioklassik.stream.laut.fm/brainradioklassik"
RADIO_STATION_LIST["Linn Jazz"]="http://radio.linn.co.uk:8000/autodj"
RADIO_STATION_LIST["Radio Swiss Jazz"]="http://www.radioswissjazz.ch/live/mp3.m3u"
RADIO_STATION_LIST["RTL 102.5"]="https://streamingv2.shoutcast.com/rtl-1025"
RADIO_STATION_LIST["Lounge Radio"]="https://stream.laut.fm/loungeradio"
RADIO_STATION_LIST["Soul Radio"]="http://soulradio02.live-streams.nl:80/live"
RADIO_STATION_LIST["The Summit FM"]="http://streamer2.legatocommunications.com/wapshq"
RADIO_STATION_LIST["WBGO"]="https://wbgo.streamguys1.com/wbgo128"
RADIO_STATION_LIST["WSM AM"]="https://stream01048.westreamradio.com/wsm-am-mp3"
RADIO_STATION_LIST["WXPN 88.5"]="https://wxpnhi.xpn.org/xpnhi"
RADIO_STATION_LIST["fip Radio"]="http://direct.fipradio.fr/live/fip-midfi.mp3"

AUDIO_SRC_FALLBACK="/home/sflip/snd/Mark Ronson feat. Bruno Mars - Uptown Funk.mp3"

# ALSA audio device to use (list with `aplay -L`)
# If device not found, this will be ignored and default device will be used.
ALSA_DEVICE="${ALSA_DEVICE:-plughw:CARD=sndrpihifiberry,DEV=0}"

ALARM_DEFAULT_DURATION=60

VOLUME_INCREMENT_INIT=60
VOLUME_INCREMENT_COUNT=15
VOLUME_INCREMENT_FREQUENCY=$((60 * 2))
VOLUME_INCREMENT_AMOUNT=5

VLC_GAIN=${VLC_GAIN:-0.9}

VLC_RC_HOST=localhost
VLC_RC_PORT=9592 # hardcoded because using lsof (_find_unused_port) may be problematic

# suffixes appended to crontab line, will be grepped for and matched lines will be deleted!
ALARM_CRON_ID="MANAGED RADIO ALARM CRON"
TIMER_CRON_ID="MANAGED RADIO TIMER CRON"

STATEDIR=/tmp/radiopi
PIDFILE_VLC="$STATEDIR/vlc.pid"
PIDFILE_INC="$STATEDIR/volume_increment.pid"
PORTFILE="$STATEDIR/vlc.port"
VOLUMEFILE="$STATEDIR/vlc.volume"
STATUSFILE="$STATEDIR/status.txt"
TMP_CRONTAB_FILE="$STATEDIR/crontab.txt"


function _is_raspberry_pi() {
    local PI_MODEL_FILE="/proc/device-tree/model"
    test -f "$PI_MODEL_FILE" && grep -q "Raspberry Pi" "$PI_MODEL_FILE"
}

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
    if [[ -f "$PIDFILE_VLC" ]]; then
        PID=$(cat $PIDFILE_VLC)
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
        "${RADIO_STATION_LIST["1LIVE"]}"
        "${RADIO_STATION_LIST["1LIVE DIGGI"]}"
        "${RADIO_STATION_LIST["WDR 2"]}"
        "${RADIO_STATION_LIST["WDR 3"]}"
        "${RADIO_STATION_LIST["WDR 4"]}"
        "${RADIO_STATION_LIST["WDR 5"]}"
        "${RADIO_STATION_LIST["Die Maus"]}"
        "${RADIO_STATION_LIST["Linn Jazz"]}"
        "${RADIO_STATION_LIST["Lounge Radio"]}"
        "${RADIO_STATION_LIST["Radio Swiss Jazz"]}"
        "${RADIO_STATION_LIST["WBGO"]}"
        "${RADIO_STATION_LIST["WSM AM"]}"
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

function _verify_vlc_volume_is_decoupled_from_system_volume() {
    if ! grep -q -E '^flat-volumes = no' '/etc/pulse/daemon.conf'; then
        cat <<-EOF
ERROR: Please decouple vlc volume from system volume by adding
'flat-volumes = no'
to your /etc/pulse/daemon.conf For details, see
https://superuser.com/questions/770028/decoupling-vlc-volume-and-system-volume
EOF
        exit 1
    fi
}

function _configure_vlc_env() {
    export DISPLAY=${DISPLAY:-":0"}
    export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-"unix:path=/run/user/$(id -u)/bus"}
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

function _update_volume_file() {
    VOLUME=$(_get_vlc_volume)
    echo "$VOLUME" > "$VOLUMEFILE"
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

function _randomly_set_station() {
    if [[ -z $RANDOM_ATTEMPTS ]]; then
        RANDOM_ATTEMPTS=0
    fi
    random_index=$((RANDOM % ${#RADIO_STATION_LIST[@]}))
    i=0
    for STATION in "${!RADIO_STATION_LIST[@]}"; do
        if [[ "$i" -eq "$random_index" ]]; then
            break
        fi
        i=$((i + 1))
    done
    (( RANDOM_ATTEMPTS=RANDOM_ATTEMPTS+1 ))
    if [[ "$RANDOM_ATTEMPTS" -ge 5 ]]; then
        echo "Maximum attempts reached! Using fallback audio source $AUDIO_SRC_FALLBACK"
        AUDIO_SRC="$AUDIO_SRC_FALLBACK"
    elif ! _test_audio_stream_url "${RADIO_STATION_LIST[$STATION]}"; then
        echo "Station $STATION does not look like an audio source. Trying another one..."
        _randomly_set_station
    else
        echo "Station randomly set to $STATION"
    fi
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
    echo "Now playing $TITLE ($AUDIO_SRC)..."
    echo "Station: $TITLE" > "$STATUSFILE"
    echo "Stream URL: $AUDIO_SRC" >> "$STATUSFILE"
    vlc "${VLC_ARGS[@]}" & echo $! > $PIDFILE_VLC
    if [[ -n "$VOLUME_INCREMENT_ENABLED" ]]; then
        echo "Volume will be incremented successively..."
        _wait_until_tcp_port_open "$VLC_RC_HOST" "$VLC_RC_PORT"
        _set_vlc_volume "$VOLUME_INCREMENT_INIT"
        (
        for (( i = 0; i < VOLUME_INCREMENT_COUNT; i++ )); do
            sleep "$VOLUME_INCREMENT_FREQUENCY"
            _set_vlc_volume "+$VOLUME_INCREMENT_AMOUNT"
            _update_volume_file
        done
        rm $PIDFILE_INC
        ) & echo $! > $PIDFILE_INC
        echo "Volume increment PID: $(cat $PIDFILE_INC)"
    else
        echo "Playing at constant volume."
    fi
    _update_volume_file
    if [[ -z "$DETACH" ]]; then
        fg # play until interrupt
        _cleanup_after_playback
    fi
}

function _stop_playback() {
    for PIDFILE in $PIDFILE_VLC $PIDFILE_INC; do
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
    done
    _cleanup_after_playback
}

function _cleanup_after_playback() {
    if [[ -f "$STATUSFILE" ]]; then
        rm "$STATUSFILE"
    fi
}

function _start_radio() {
    local QUERY_OR_URL="$1"
    if [[ -n "$QUERY_OR_URL" && -n "${RADIO_STATION_LIST[$QUERY_OR_URL]}" ]]; then
        AUDIO_SRC="${RADIO_STATION_LIST[$QUERY_OR_URL]}"
        TITLE="$QUERY_OR_URL"
    elif [[ -n "$QUERY_OR_URL" ]] && _test_audio_stream_url "$QUERY_OR_URL"; then
        AUDIO_SRC="$QUERY_OR_URL"
        TITLE="$AUDIO_SRC"
    elif [[ -n "$NON_INTERACTIVE" ]]; then
        echo "ERROR: Station '$QUERY_OR_URL' not found"
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
    echo "---------------------------------"
    echo "Radio started at $(date +'%F %R')"
    _start_playback "$TITLE" "$AUDIO_SRC"
}

function _print_status_msg() {
    if [[ -f "$STATUSFILE" ]]; then
        echo "Status: on"
        cat "$STATUSFILE"
        if [[ -f $PIDFILE_INC ]]; then
            echo "Volume increment: on"
        else
            echo "Volume increment: off"
        fi
        if has crontab; then
            _echo_timer_status
        fi
    else
        echo "Status: off"
    fi
    if has crontab; then
        _echo_alarm_status
    fi
}

function _append_once() {
    FILE="$1"
    LINE="$2"
    grep -q -F "$LINE" "$FILE"  || echo "$LINE" >> "$FILE"
}


function _open_crontab() {
    if ! crontab -l >/dev/null 2>&1; then
        echo "ERROR: You don't have a crontab file yet. Create one with \`crontab -e\`."
        exit 1
    fi
    crontab -l > "$TMP_CRONTAB_FILE"
}

function _close_crontab() {
    # cat "$TMP_CRONTAB_FILE" # debug
    crontab < "$TMP_CRONTAB_FILE"
}

function _echo_timer_status() {
    if crontab -l >/dev/null 2>&1; then
        _open_crontab
        TIME=$(gawk "/stop.*$TIMER_CRON_ID/ {print \$2 \":\" \$1}" < "$TMP_CRONTAB_FILE")
        if [[ -n "$TIME" ]]; then
            echo "Timer: enabled"
            echo "Timer set to: $TIME"
        else
            echo "Timer: disabled"
        fi
    else
        echo "Timer: disabled"
    fi
}

function _echo_alarm_status() {
    if crontab -l >/dev/null 2>&1; then
        _open_crontab
        TIME=$(gawk "/start.*$ALARM_CRON_ID/ {print \$2 \":\" \$1}" < "$TMP_CRONTAB_FILE")
        if [[ -n "$TIME" ]]; then
            echo "Alarm: enabled"
            echo "Alarm time: $TIME"
        else
            echo "Alarm: disabled"
        fi
    else
        echo "Alarm: disabled"
    fi
}

function _set_sleep_timer() {
    local DURATION="$1"
    HOUR=$(  date -d "$DURATION minutes" +'%H')
    MINUTE=$(date -d "$DURATION minutes" +'%M')
    STOP_LINE="$MINUTE $HOUR * * * \$RADIO_CMD stop >>\$RADIO_LOG 2>&1 # $TIMER_CRON_ID"
    _open_crontab
    _disable_timer_inner
    _append_once "$TMP_CRONTAB_FILE" "RADIO_CMD=$DIR/$SELF"
    _append_once "$TMP_CRONTAB_FILE" "RADIO_LOG=$STATEDIR/radio.log"
    _append_once "$TMP_CRONTAB_FILE" "$STOP_LINE"
    _close_crontab
    echo "Set sleep timer to $HOUR:$MINUTE."
    if ! pgrep crond >/dev/null; then
        echo "WARNING: Make sure your cron service is running!"
    fi
}

function _disable_timer() {
    _open_crontab
    _disable_timer_inner
    _close_crontab
}

function _enable_alarm() {
    local ALPHA_HOUR="$1"
    local ALPHA_MINUTE="$2"
    local DURATION="$3"
    local OMEGA_HOUR
    local OMEGA_MINUTE
    OMEGA_HOUR=$(  date -d "$ALPHA_HOUR:$ALPHA_MINUTE $DURATION minutes" +'%H')
    OMEGA_MINUTE=$(date -d "$ALPHA_HOUR:$ALPHA_MINUTE $DURATION minutes" +'%M')
    ALPHA_LINE="$ALPHA_MINUTE $ALPHA_HOUR * * * \$RADIO_CMD start -r -w >>\$RADIO_LOG 2>&1 # $ALARM_CRON_ID"
    OMEGA_LINE="$OMEGA_MINUTE $OMEGA_HOUR * * * \$RADIO_CMD stop        >>\$RADIO_LOG 2>&1 # $ALARM_CRON_ID"
    _open_crontab
    _disable_alarm_inner
    _append_once "$TMP_CRONTAB_FILE" "RADIO_CMD=$DIR/$SELF"
    _append_once "$TMP_CRONTAB_FILE" "RADIO_LOG=$STATEDIR/radio.log"
    _append_once "$TMP_CRONTAB_FILE" "$ALPHA_LINE"
    _append_once "$TMP_CRONTAB_FILE" "$OMEGA_LINE"
    _close_crontab
    echo "Scheduled alarm for $ALPHA_HOUR:$ALPHA_MINUTE."
    if ! pgrep crond >/dev/null; then
        echo "WARNING: Make sure your cron service is running!"
    fi
}

function _disable_alarm() {
    _open_crontab
    _disable_alarm_inner
    _close_crontab
    echo "Removed scheduled alarm."
}

function _disable_alarm_inner() {
    gawk -i inplace -v rmv="$ALARM_CRON_ID" '!index($0,rmv)' "$TMP_CRONTAB_FILE"
}

function _disable_timer_inner() {
    gawk -i inplace -v rmv="$TIMER_CRON_ID" '!index($0,rmv)' "$TMP_CRONTAB_FILE"
}

function _main() {

    mkdir -p "$STATEDIR"

    if _is_raspberry_pi; then
        _verify_vlc_volume_is_decoupled_from_system_volume
    fi
    _configure_vlc_env

    while [[ $# -gt 0 ]]; do
        ARG="$1"
        case $ARG in
            help|--help|-h)
                _print_help_msg
                exit 0
                ;;
            --non-interactive|-n)
                NON_INTERACTIVE=1
                shift
                ;;
            --random|-r)
                _randomly_set_station
                NON_INTERACTIVE=1
                QUERY_OR_URL="$STATION"
                shift
                ;;
            --wake-up|-w)
                VOLUME_INCREMENT_ENABLED=1
                shift
                ;;
            list)
                _list_stations
                exit 0
                ;;
            status)
                _print_status_msg
                exit 0
                ;;
            start)
                DETACH=1
                shift
                ;;
            stop)
                _stop_playback
                _disable_timer
                exit 0
                ;;
            nosleep)
                _disable_timer
                echo "Removed scheduled stop."
                exit 0
                ;;
            sleep)
                require crontab
                if [[ -n "$2" && "$2" =~ ^[0-9]{1,3}$ ]]; then
                    DURATION="$2"
                else
                    echo "ERROR: Duration required in minutes."
                    exit 1
                fi
                shift
                if _is_playing; then
                    _set_sleep_timer "$DURATION"
                    exit 0
                else
                    echo "ERROR: No radio playing."
                    exit 1
                fi
                ;;
            volume)
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
                    echo "ERROR: No radio playing."
                    exit 1
                fi
                ;;
            enable)
                require crontab
                if [[ -n "$2" && "$2" =~ ^[0-9]{1,2}$ && -n "$3" && "$3" =~ ^[0-9]{1,2}$ ]]; then
                    if [[ -n "$4" && "$4" =~ ^[0-9]{1,2}$ ]]; then
                        DURATION="$4"
                    else
                        DURATION="$ALARM_DEFAULT_DURATION"
                    fi
                else
                    echo "ERROR: Hour and minute required as separate arguments."
                    exit 1
                fi
                _enable_alarm "$2" "$3" "$DURATION"
                exit 0
                ;;
            disable)
                require crontab
                _disable_alarm
                exit 0
                ;;
            *)
                QUERY_OR_URL=$ARG
                shift
                ;;
        esac
    done

    if _is_playing; then
        echo "ERROR: Radio already playing."
        exit 1
    else
        _start_radio "$QUERY_OR_URL"
    fi

}

_main "$@"
