#!/bin/bash
set -euo pipefail

# dependencies
for cmd in pactl parec ffmpeg; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "error: '$cmd' is not installed install it to use this script" >&2
    exit 1
  fi
done

# find default sink
ORIG_SINK=$(pactl info | awk '/Default Sink:/ {print $3}')
if ! pactl list short sinks | awk '{print $2}' | grep -qx "$ORIG_SINK"; then
  echo "error: original default sink '$ORIG_SINK' not found." >&2
  exit 1
fi

LOOP_SINK="loopback_sink"
loop_sink_module_id=""
loopback_module_id=""

# restore sink and unload modules
cleanup() {
  echo "cleaning up..."

  CURRENT_DEF=$(pactl info | awk '/Default Sink:/ {print $3}')
  if [ "$CURRENT_DEF" != "$ORIG_SINK" ]; then
    pactl set-default-sink "$ORIG_SINK"
    echo "restored default sink to $ORIG_SINK"
  fi

  if [ -n "$loopback_module_id" ]; then
    pactl unload-module "$loopback_module_id" && \
      echo "unloaded module-loopback ID $loopback_module_id"
  fi

  if [ -n "$loop_sink_module_id" ]; then
    pactl unload-module "$loop_sink_module_id" && \
      echo "unloaded module-null-sink ID $loop_sink_module_id"
  fi
}
trap cleanup EXIT

# create null sink if needed
if ! pactl list short sinks | awk '{print $2}' | grep -qx "$LOOP_SINK"; then
  loop_sink_module_id=$(pactl load-module module-null-sink \
    sink_name="$LOOP_SINK" \
    sink_properties=device.description=Loopback)
  echo "loaded module-null-sink ID $loop_sink_module_id"
else
  echo "loopback sink '$LOOP_SINK' already exists."
fi

# make loopback sink the default
CURRENT_DEF=$(pactl info | awk '/Default Sink:/ {print $3}')
if [ "$CURRENT_DEF" != "$LOOP_SINK" ]; then
  pactl set-default-sink "$LOOP_SINK"
  echo "default sink set to $LOOP_SINK"
fi

# restore audio to og output
loopback_module_id=$(pactl load-module module-loopback \
  source="${LOOP_SINK}.monitor" \
  sink="$ORIG_SINK" \
  latency_msec=1)
echo "loaded module-loopback ID $loopback_module_id"

# recording
OUTPUT_DIR="$HOME"
mkdir -p "$OUTPUT_DIR"
FILENAME="$OUTPUT_DIR/audio_$(date +'%Y-%m-%d_%H-%M-%S').opus"

echo "recording to: $FILENAME"
echo "press ctrl+c to stop recording and cleanup."

parec -d "${LOOP_SINK}.monitor" \
      --format=s16le \
      --rate=44100 \
      --channels=2 | \
ffmpeg -hide_banner -loglevel error \
       -f s16le -ar 44100 -ac 2 -i - \
       -c:a libopus -b:a 128k \
       "$FILENAME"

echo "recording finished: $FILENAME"
# cleanup function
