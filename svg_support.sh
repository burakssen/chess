#!/bin/bash

# Check if a file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <filename>"
  exit 1
fi

# Check if the file exists
if [ ! -f "$1" ]; then
  echo "Error: File '$1' does not exist."
  exit 1
fi

# Check if the file is writable
if [ ! -w "$1" ]; then
  echo "Error: File '$1' is not writable."
  exit 1
fi

# Determine the OS type
OS_TYPE=$(uname)

# Replace //#define SUPPORT_FILEFORMAT_SVG with #define SUPPORT_FILEFORMAT_SVG
if [[ "$OS_TYPE" == "Darwin" ]]; then
  # macOS
  if sed -i '' 's|//#define SUPPORT_FILEFORMAT_SVG      1|#define SUPPORT_FILEFORMAT_SVG      1|' "$1"; then
    echo "Successfully updated '$1'."
  else
    echo "Error: Failed to update the file."
    exit 1
  fi
else
  # Linux
  if sed -i 's|//#define SUPPORT_FILEFORMAT_SVG      1|#define SUPPORT_FILEFORMAT_SVG      1|' "$1"; then
    echo "Successfully updated '$1'."
  else
    echo "Error: Failed to update the file."
    exit 1
  fi
fi
