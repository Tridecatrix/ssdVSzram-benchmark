#!/bin/bash
# Raw zram time-series data extractor
# Outputs raw adjusted values for each time interval in CSV format

RESULT_DIR=$1
SKIP_ENTRIES=${2:-10}  # Default to 10 entries if not provided
DISABLE_STARTUP_SKIP=${3:-false}  # Default to false (startup skipping enabled)
STARTUP_THRESHOLD=${4:-10}  # Default to 10% threshold

if [[ -z "$RESULT_DIR" ]]; then
    echo "Usage: $0 <result_directory> [skip_entries] [disable_startup_skip] [startup_threshold]"
    echo "  result_directory: Directory containing zram_usage.txt"
    echo "  skip_entries: Number of mmstat entries to skip at start (default: 10)"
    echo "  disable_startup_skip: Set to 'true' to disable startup detection (default: false)"
    echo "  startup_threshold: Percentage threshold for startup detection (default: 10)"
    exit 1
fi

# Single awk command to process all data
awk -v skip_entries="$SKIP_ENTRIES" -v disable_startup_skip="$DISABLE_STARTUP_SKIP" -v startup_threshold="$STARTUP_THRESHOLD" 'BEGIN {
    first_data_bytes = 0
    first_compr_bytes = 0
    first_same_pages = 0
    first_huge_pages = 0
    first_set = 0
    entries_skipped = 0
    startup_skipped = 0
    entry_count = 0
    
    # Print CSV header
    print "entry_number,adjusted_data_bytes,adjusted_compr_bytes,adjusted_huge_pages,adjusted_same_pages,compression_ratio,data_mb,compr_mb"
}

$1 == "mmstat" {
    # Get DATA and TOTAL columns (fields 2 and 3)
    data_bytes = $2
    compr_bytes = $3
    same_pages = $6     # same_pages is field 6
    huge_pages = $9     # huge_pages is field 9
    
    entry_count++
    
    # Skip first N entries unconditionally
    if (entry_count <= skip_entries) {
        entries_skipped++
        next
    }
    
    # Set first data value for startup baseline (after entry skip)
    if (!first_set) {
        first_data_bytes = data_bytes
        first_compr_bytes = compr_bytes
        first_same_pages = same_pages
        first_huge_pages = huge_pages
        first_set = 1
    }
    
    # Skip startup entries (within threshold % of initial value) - only if not disabled
    if (disable_startup_skip != "true") {
        diff = (data_bytes > first_data_bytes) ? data_bytes - first_data_bytes : first_data_bytes - data_bytes
        percent_diff = (first_data_bytes > 0) ? (diff / first_data_bytes) * 100 : 0
        
        if (percent_diff <= startup_threshold) {
            startup_skipped++
            next
        }
    }
    
    # Calculate adjusted values (subtract baseline)
    adjusted_data = data_bytes - first_data_bytes
    adjusted_compr = compr_bytes - first_compr_bytes
    adjusted_huge_pages = huge_pages - first_huge_pages
    adjusted_same_pages = same_pages - first_same_pages
    
    # Calculate compression ratio
    compression_ratio = (adjusted_compr > 0) ? adjusted_data / adjusted_compr : 0
    
    # Convert to MB for easier reading
    data_mb = adjusted_data / 1048576
    compr_mb = adjusted_compr / 1048576
    
    # Output the raw data for this time interval
    printf "%d,%d,%d,%d,%d,%.4f,%.2f,%.2f\n", 
           entry_count - entries_skipped - startup_skipped,
           adjusted_data, 
           adjusted_compr, 
           adjusted_huge_pages, 
           adjusted_same_pages,
           compression_ratio,
           data_mb,
           compr_mb
}

END {
    # Print summary to stderr so it does not interfere with CSV output
    printf "# Summary: Initial entries skipped: %d, Startup entries skipped: %d, Total data entries output: %d\n", entries_skipped, startup_skipped, (entry_count - entries_skipped - startup_skipped) > "/dev/stderr"
}' "$RESULT_DIR/zram_usage.txt"