#!/usr/bin/env bash

trap _bail SIGINT SIGTERM

declare _last_player
declare _last_kill
_nuke() {
  local _player=$1
  local _kill=$2
  [[ -z "$_player" ]] && return 0
  [[ -z "$_kill" ]] && return 0
  _last_player=$_player
  _last_kill=$_kill
  # killall -9 mpv ffplay vlc cvlc >&/dev/null || true
  killall -9 "$_player" >&/dev/null || true
  # pgrep -ai --signal 9 "${_player}.*${_kill}" >&/dev/null || true
}

_bail() {
  trap - SIGINT SIGTERM
  _nuke "$_last_player" "$_last_kill"
  kill 0
}

_ffplay() {
  local _url=$1
  [[ -z "$_url" ]] && return 1

  ~/ffmpeg-master-latest-linux64-gpl/bin/ffplay \
    -fs \
    -an \
    -sn \
    -alwaysontop \
    -noborder \
    -skip_alpha true \
    -allowed_media_types video \
    -infbuf \
    -framedrop \
    -bug trunc \
    -strict 1 \
    -f_strict 1 \
    -err_detect ignore_err \
    -f_err_detect ignore_err \
    -genpts \
    -drp 1 \
    "$_url" 2>&1
    # -autoexit \
    # -max_delay $((5 * 100000)) \
    # -rtsp_transport http \
    # -rtsp_flags prefer_tcp \
    # -reorder_queue_size 1120 \
    # -load_plugin hevc_hw \
    # -async_depth 8 \
    # -num_capture_buffers 32 \
    # -num_output_buffers 32 \
    # -sync video \
    # -avioflags direct \
    # -gpu_copy on \
    # -avioflags direct \
    # -flags unaligned \
    # -flags2 chunks \
    # -ec favor_inter \
    # -threads 0 \
    # -lowres 1 \
    # -buffer_size 0 \
    # -fflags discardcorrupt,nofillin \
    # -apply_defdispwin true \
    # -seek2any true \
    # -use_wallclock_as_timestamps true \
    # -max_delay 0 \
    # -pkt_size 0 \
    # -skip_estimate_duration_from_pts \
    # -protocol_whitelist rtp,file,udp,tcp \
    # -idct 3 \
    # -indexmem $((1024 * 1024 * 64)) \
    # -rtbufsize $((1024 * 1024 * 64)) \
}

_mpv() {
  local _url=$1
  local _screen=$2
  [[ -z "$_url" ]] && return 1
  [[ -z "$_screen" ]] && _screen=0

  mpv \
   --fs \
   --fs-screen="$_screen" \
   --ontop-level=10 \
   --no-correct-pts \
   --untimed \
   --no-audio \
   --video-latency-hacks=yes \
   --hwdec \
   --hwdec=vaapi \
   --opengl-glfinish=yes \
   --opengl-swapinterval=0 \
   --framedrop=no \
   --speed=1.01 \
    "$_url" 2>&1
   # --fps=15 \
}

_vlc() {
  local _url=$1
  local _screen=$2
  [[ -z "$_url" ]] && return 1
  [[ -z "$_screen" ]] && _screen=0

  vlc \
    --qt-fullscreen-screennumber "$_screen" \
    --autoscale \
    --no-audio \
    --play-and-exit \
    --no-mouse-events \
    --no-keyboard-events \
    --fullscreen \
    --no-video-title-show \
    --no-playlist-tree \
    --no-metadata-network-access \
    --no-interact \
    --no-video-deco \
    --quiet-synchro \
    --skip-frames \
    --drop-late-frames \
    --no-auto-preparse \
    --no-metadata-network-access \
    "$_url" 2>&1
    # --glconv glconv_vaapi_x11 \
}


_infinite_cam() {
  local _kill=$1
  local _player=$2
  local _url=$3
  local _screen=$4

  [[ -z "$_url" ]] && return 1
  [[ -z "$_kill" ]] && return 1
  [[ -z "$_player" ]] && return 1

  while true ; do
    _nuke "$_player" "$_kill"

    exec 3< <("_${_player}" "$_url" "${_screen}")

    declare -i _errors=0
    declare -i _delay=0
    declare _out
    declare -i _countdown=$((2 * 60))
    while ((_countdown-- > 0 )); do
      sleep 1

      while read -t 1 _out <&3 ; do
        [[ -z "$_out" ]] && continue
        # if echo "$_out" | grep -v 'Waiting for VPS/SPS/PPS' | grep -qiE 'error|could not find' ; then
        if echo "$_out" | grep -qiE 'error|could not find' ; then
          let ++_errors
        fi

        if [[ "$_player" == "ffplay" ]] ; then
          local _maybe_delay=$(echo "$_out" | grep 'fd=' | sed -e 's/^.*fd= *//' -e 's/ .*$//')

          if [[ "$_maybe_delay" =~ ^[0-9][0-9]*$ ]]; then
            _delay=$_maybe_delay
          fi
        fi

        echo "[OUT $_errors] $_out"
      done

      # if ((_delay < 10)); then
      #   let ++_countdown
      # fi

      if ((_delay > 200 || _errors > 15)); then
        let _delay=0
        let _errors=0
        let _countdown=0
      else
        echo "[NOOUT $_errors] $_out"
        ((_errors > 0)) && let --_errors || true
      fi
    done

    _nuke "$_player" "$_kill"
  done
}

