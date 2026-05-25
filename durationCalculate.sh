#!/bin/bash

# Initialize total duration
total_duration=0

# Function to convert duration from seconds to a readable format
convert_duration() {
  local total_seconds=$1
  printf "%02d:%02d:%02d\n" $((total_seconds / 3600)) $((total_seconds % 3600 / 60)) $((total_seconds % 60))
}

# Loop through all media files in the current directory
for file in *.mp4 *.mkv *.avi *.mov *.wmv *.flv *.mp3 *.wav *.webm *.ts; do
  # Check if the file exists
  if [[ -f "$file" ]]; then
    # Get the duration using ffprobe
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")

    # Check if duration is a valid number
    if [[ $duration =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      # Add to total duration
      total_duration=$(echo "$total_duration + $duration" | bc)
      # Print the duration of the current file
      echo "Duration of $file: $(convert_duration ${duration%.*})"
    else
      echo "Could not get duration for $file"
    fi
  fi
done

# Print the total duration
echo "Total Duration: $(convert_duration ${total_duration%.*})"
