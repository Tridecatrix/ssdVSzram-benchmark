#!/bin/bash
# filepath: c:\Users\adnan\Desktop\Work\2025\COMP4550_Honours\tera_applications\spark\scripts\parse_zram_results.sh

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
awk -v skip_entries="$SKIP_ENTRIES" -v disable_startup_skip="$DISABLE_STARTUP_SKIP" -v startup_threshold="$STARTUP_THRESHOLD" '
BEGIN {
    data_total = 0
    compr_total = 0
    count = 0
    first_data_bytes = 0
    first_compr_bytes = 0
    startup_skipped = 0
    ratio_total = 0
    ratio_sum_sq = 0
    max_data = 0
    max_compr = 0
    first_set = 0
    entries_skipped = 0
    entry_count = 0
    
    # New variables for huge_pages and same_pages
    huge_pages_total = 0
    same_pages_total = 0
    max_huge_pages = 0
    max_same_pages = 0
    huge_pages_at_max_data = 0
    same_pages_at_max_data = 0
}

$1 == "mmstat" {
    # Get DATA and TOTAL columns (fields 2 and 3)
    data_bytes = $2
    compr_bytes = $3
    same_pages = $7     # same_pages is field 7
    huge_pages = $9     # huge_pages is field 9
    
    entry_count++
    
    # Skip first N entries unconditionally
    if (entry_count <= skip_entries) {
        entries_skipped++
        next
    }
    
    # Set first data value for startup baseline (after time skip)
    if (!first_set) {
        first_data_bytes = data_bytes
        first_compr_bytes = compr_bytes
        first_same_pages = same_pages
        first_huge_pages = huge_pages
        first_set = 1
        next
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
    
    # Accumulate data
    data_total += data_bytes - first_data_bytes
    compr_total += compr_bytes - first_compr_bytes
    huge_pages_total += huge_pages - first_huge_pages
    same_pages_total += same_pages - first_same_pages
    
    # Track maximums (subtract first_data_bytes like for totals)
    adjusted_data = data_bytes - first_data_bytes
    adjusted_compr = compr_bytes - first_compr_bytes
    adjusted_huge_pages = huge_pages - first_huge_pages
    adjusted_same_pages = same_pages - first_same_pages
    
    if (adjusted_data > max_data) {
        max_data = adjusted_data
        max_compr = adjusted_compr
        huge_pages_at_max_data = adjusted_huge_pages
        same_pages_at_max_data = adjusted_same_pages
    }
    max_huge_pages = (max_huge_pages > adjusted_huge_pages) ? max_huge_pages : adjusted_huge_pages
    max_same_pages = (max_same_pages > adjusted_same_pages) ? max_same_pages : adjusted_same_pages
    
    count++
    
    # Calculate ratio and accumulate for standard deviation (use adjusted values)
    if (adjusted_compr > 0) {
        ratio = adjusted_data / adjusted_compr
        ratio_total += ratio
        ratio_sum_sq += ratio * ratio
    }
}

END {
    if (count == 0) {
        print "No entries found (or all entries were skipped)"
        print "Initial entries skipped: " entries_skipped
        print "Startup entries skipped: " startup_skipped
        exit 1
    }
    
    # Calculate averages in MiB
    avg_data = data_total / count / 1048576
    avg_compr = compr_total / count / 1048576
    avg_ratio = ratio_total / count
    avg_huge_pages = huge_pages_total / count
    avg_same_pages = same_pages_total / count
    
    # Calculate average incompressible data (huge pages * page size)
    # Standard page size is 4096 bytes (4 KiB)
    page_size = 4096
    avg_incompressible_bytes = avg_huge_pages * page_size
    avg_incompressible_mb = avg_incompressible_bytes / 1048576
    
    # Calculate standard deviation of compression ratio
    if (count > 1) {
        variance = (ratio_sum_sq - (ratio_total * ratio_total / count)) / (count - 1)
        ratio_stddev = sqrt(variance)
    } else {
        ratio_stddev = 0
    }
    
    # Convert max values to MiB
    max_data_mb = max_data / 1048576
    max_compr_mb = max_compr / 1048576
    ratio_at_max = (max_compr > 0) ? max_data / max_compr : 0
    
    # Output as CSV
    printf "AVG_DATA_SIZE_MB,%.2f\n", avg_data
    printf "AVG_COMPR_SIZE_MB,%.2f\n", avg_compr
    printf "AVG_RATIO,%.2f\n", avg_ratio
    printf "RATIO_STDDEV,%.4f\n", ratio_stddev
    printf "MAX_DATA_SIZE_MB,%.2f\n", max_data_mb
    printf "MAX_COMPR_SIZE_MB,%.2f\n", max_compr_mb
    printf "RATIO_AT_MAX_DATA_SIZE,%.2f\n", ratio_at_max
    printf "AVG_HUGE_PAGES,%.0f\n", avg_huge_pages
    printf "HUGE_PAGES_AT_MAX_DATA_SIZE,%.0f\n", huge_pages_at_max_data
    printf "MAX_HUGE_PAGES,%.0f\n", max_huge_pages
    printf "AVG_SAME_PAGES,%.0f\n", avg_same_pages
    printf "SAME_PAGES_AT_MAX_DATA_SIZE,%.0f\n", same_pages_at_max_data
    printf "MAX_SAME_PAGES,%.0f\n", max_same_pages
    printf "AVG_INCOMPRESSIBLE_DATA_MB,%.2f\n", avg_incompressible_mb
    printf "INITIAL_ENTRIES_SKIPPED,%d\n", entries_skipped
    printf "STARTUP_ENTRIES_SKIPPED,%d\n", startup_skipped
}
' "$RESULT_DIR/zram_usage.txt"