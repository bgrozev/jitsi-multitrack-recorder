#!/bin/bash
# depends on ffprobe, ffmpeg, jq, bc, awk

# passed mka file is flatten and converted to mp3 where all streams are mixed into one mono channel

input_mka_file="$1"
output_mp3_file="$2"

# Step 1: Get the JSON output from ffprobe
ffprobe_output=$(ffprobe -i $1 -show_entries stream=index,start_time -v quiet -select_streams a -print_format json)

# Step 2: Parse the JSON to extract audio streams and their start times using jq
streams=$(echo "$ffprobe_output" | jq -r '.streams[] | "\(.index) \(.start_time)"')

filter_complex=""
amix_inputs=0

## Step 3: Build the filter_complex string dynamically
while IFS= read -r stream; do
  index=$(echo "$stream" | cut -d' ' -f1)
  start_time=$(echo "$stream" | cut -d' ' -f2)

  # Convert start time to milliseconds (ffmpeg uses milliseconds for adelay)
  delay=$(echo "$start_time * 1000" | bc | awk '{printf "%.0f\n", $0}')

  # Create adelay filter for this stream and append it to filter_complex
  filter_complex+="[0:a:$index]adelay=${delay}|${delay}[a$index];"
  amix_inputs=$((amix_inputs + 1))
done <<< "$streams"

# Step 4: Combine all the delayed tracks using amix
filter_complex+=$(for i in $(seq 0 $((amix_inputs - 1))); do echo -n "[a$i]"; done)
filter_complex+="amix=inputs=$amix_inputs"

# Step 5: Build and execute the ffmpeg command
ffmpeg -i "$input_mka_file" -filter_complex "$filter_complex" -c:a libmp3lame -q:a 2 "$output_mp3_file"

echo "MP3 file has been generated as $output_mp3_file."
