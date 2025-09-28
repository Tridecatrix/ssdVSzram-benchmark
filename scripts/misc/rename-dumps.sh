#!/bin/bash

# This script renames files to fill gaps in their numbering sequences
# based on a predefined list of benchmark names.

# Predefined list of DaCapo benchmark names.
dacapo_benchs="avrora batik biojava cassandra eclipse fop graphchi h2 h2o jme jython kafka luindex lusearch pmd spring sunflow tomcat tradebeans tradesoap xalan zxing"

# Iterate over each benchmark name provided in the list.
for benchmark in $dacapo_benchs; do

  # Check if files for this benchmark actually exist before processing.
  # The 'shopt' commands help handle cases with no matching files gracefully.
  shopt -s nullglob
  files=(${benchmark}-*.hprof)
  shopt -u nullglob

  if [ ${#files[@]} -eq 0 ]; then
    # Optional: uncomment the line below if you want to be notified about missing benchmarks.
    # echo "No files found for benchmark: ${benchmark}. Skipping."
    continue
  fi

  echo "Processing benchmark: ${benchmark}"

  # Initialize a counter for new sequential numbering.
  count=0

  # List all files for the current benchmark, sorting them numerically ('-v').
  # The '2>/dev/null' suppresses errors if no files match a benchmark name.
  for old_file in $(ls -v ${benchmark}-*.hprof 2>/dev/null); do
    
    # Define the new filename with the sequential count.
    new_file="${benchmark}-${count}.hprof"

    # Only perform a rename if the old and new filenames are different.
    if [ "${old_file}" != "${new_file}" ]; then
      echo "  -> Renaming '${old_file}' to '${new_file}'"
      mv "${old_file}" "${new_file}"
    fi
    
    # Increment the counter for the next file.
    count=$((count + 1))
  done
done

echo "Renaming complete."