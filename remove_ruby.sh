#!/bin/bash
# parses currently selected text and removes furigana written in ruby format
# also breaks images and other things if copied to clipboard

# uncomment if didn't install clipnotify globally
# export PATH="./:$PATH"

# list of required commands
required_commands=("xsel" "sed" "clipnotify")

# check if each required command is available
for cmd in "${required_commands[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "error: required command '$cmd' not found." >&2
    exit 1
  fi
done

remove_furigana() {
  echo "$1" | sed -E 's/｜[^[:space:]]+//g' | sed -E 's/（[^）]+）//g'
}

while clipnotify; do
  selected_text="$(xsel)"
  copied_text="$(xsel -b)"

  if [[ $selected_text != *"file:///"* ]]; then
    modified_text_primary="$(remove_furigana "$selected_text")"
    echo -n "$modified_text_primary" | xsel -i
  fi

  if [[ $copied_text != *"file:///"* ]]; then
    modified_text_clipboard="$(remove_furigana "$copied_text")"
    echo -n "$modified_text_clipboard" | xsel -bi
  fi
done
