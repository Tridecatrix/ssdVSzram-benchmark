#!/usr/bin/env python3
"""
Consolidate ZRAM compression data from multiple benchmarks and dump numbers into a master table.

This script reads zram.csv files from each benchmark-dump/device combination and creates
a consolidated pandas DataFrame with all metrics. Unlike the original version, this
handles directory names in the format "benchmark-dump_number" and separates them into
individual columns.

The script automatically excludes the last dump for each benchmark (e.g., xalan-3 if 
xalan has dumps 0,1,2,3) since these tend to be considerably smaller as the benchmark
may be wrapping up.
"""

import pandas as pd
import os
import sys
from pathlib import Path
import re


def parse_zram_csv(filepath):
    """Parse a zram.csv file and return a dictionary of metrics."""
    metrics = {}
    
    if not os.path.exists(filepath):
        return None
        
    try:
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                if ',' in line:
                    key, value = line.split(',', 1)
                    try:
                        # Convert to float if possible, otherwise keep as string
                        metrics[key] = float(value)
                    except ValueError:
                        metrics[key] = value
        return metrics
    except Exception as e:
        print(f"Error parsing {filepath}: {e}")
        return None


def parse_benchmark_dump_name(dirname):
    """
    Parse a directory name in format 'benchmark-dump_number' into separate components.
    
    Args:
        dirname (str): Directory name like 'avrora-1', 'batik-11', etc.
        
    Returns:
        tuple: (benchmark_name, dump_number) or (None, None) if parsing fails
    """
    # Match pattern: benchmark_name-number
    match = re.match(r'^(.+)-(\d+)$', dirname)
    
    if match:
        benchmark_name = match.group(1)
        dump_number = int(match.group(2))
        return benchmark_name, dump_number
    else:
        print(f"Warning: Could not parse benchmark-dump directory name: {dirname}")
        return None, None


def consolidate_zram_data(data_dir):
    """
    Consolidate all zram.csv files from the given data directory.
    Excludes the last dump for each benchmark as they tend to be smaller.
    
    Args:
        data_dir (str): Path to the data directory containing benchmark-dump subdirs
        
    Returns:
        pd.DataFrame: Consolidated dataframe with all metrics
    """
    all_data = []
    benchmark_max_dumps = {}  # Track the maximum dump number for each benchmark
    
    data_path = Path(data_dir)
    if not data_path.exists():
        raise FileNotFoundError(f"Data directory not found: {data_dir}")
    
    # Get all benchmark-dump directories
    benchmark_dump_dirs = [d for d in data_path.iterdir() if d.is_dir()]
    
    # First pass: identify the maximum dump number for each benchmark
    print("Identifying maximum dump numbers for each benchmark...")
    for benchmark_dump_dir in benchmark_dump_dirs:
        dirname = benchmark_dump_dir.name
        benchmark_name, dump_number = parse_benchmark_dump_name(dirname)
        
        if benchmark_name is not None and dump_number is not None:
            if benchmark_name not in benchmark_max_dumps:
                benchmark_max_dumps[benchmark_name] = dump_number
            else:
                benchmark_max_dumps[benchmark_name] = max(benchmark_max_dumps[benchmark_name], dump_number)
    
    print("Maximum dump numbers by benchmark:")
    for benchmark, max_dump in sorted(benchmark_max_dumps.items()):
        print(f"  {benchmark}: {max_dump} (excluding dump {max_dump})")
    
    # Second pass: collect data, excluding the last dump for each benchmark
    excluded_count = 0
    for benchmark_dump_dir in benchmark_dump_dirs:
        dirname = benchmark_dump_dir.name
        benchmark_name, dump_number = parse_benchmark_dump_name(dirname)
        
        if benchmark_name is None or dump_number is None:
            continue  # Skip directories that don't match expected pattern
        
        # Skip if this is the last dump for this benchmark
        if dump_number == benchmark_max_dumps[benchmark_name]:
            excluded_count += 1
            print(f"Excluding {benchmark_name} dump {dump_number} (last dump for this benchmark)")
            continue
        
        # Get all zram device directories (zram0, zram1, zram2, etc.)
        device_dirs = [d for d in benchmark_dump_dir.iterdir() 
                      if d.is_dir() and d.name.startswith('zram')]
        
        for device_dir in device_dirs:
            device_name = device_dir.name
            zram_csv_path = device_dir / 'zram.csv'
            
            metrics = parse_zram_csv(zram_csv_path)
            
            if metrics is not None:
                # Add identifying columns
                metrics['benchmark'] = benchmark_name
                metrics['dump_number'] = dump_number
                metrics['device'] = device_name
                all_data.append(metrics)
                print(f"Loaded data for {benchmark_name} dump {dump_number} on {device_name}")
            else:
                print(f"Warning: No data found for {benchmark_name} dump {dump_number} on {device_name}")
    
    print(f"\nExcluded {excluded_count} benchmark-dump combinations (last dumps)")
    
    if not all_data:
        raise ValueError("No zram.csv files found in the data directory after excluding last dumps")
    
    # Create DataFrame
    df = pd.DataFrame(all_data)
    
    # Reorder columns to put identifiers first
    identifier_cols = ['benchmark', 'dump_number', 'device']
    metric_cols = [col for col in df.columns if col not in identifier_cols]
    df = df[identifier_cols + sorted(metric_cols)]
    
    return df


def main():
    if len(sys.argv) != 2:
        print("Usage: python consolidate_zram_data_dumps.py <data_directory>")
        print("Example: python consolidate_zram_data_dumps.py ../data/2025-10-22-time-22-35-51-dump-compression")
        sys.exit(1)
    
    data_dir = sys.argv[1]
    
    try:
        print(f"Consolidating ZRAM data from: {data_dir}")
        df = consolidate_zram_data(data_dir)
        
        print(f"\nConsolidated {len(df)} records from {df['benchmark'].nunique()} benchmarks, "
              f"{df['dump_number'].nunique()} unique dump numbers, and {df['device'].nunique()} devices")
        
        # Display summary
        print(f"\nBenchmarks: {sorted(df['benchmark'].unique())}")
        print(f"Dump numbers: {sorted(df['dump_number'].unique())}")
        print(f"Devices: {sorted(df['device'].unique())}")
        
        # Save to CSV
        output_path = Path(data_dir) / 'zram_consolidated.csv'
        df.to_csv(output_path, index=False)
        print(f"\nConsolidated data saved to: {output_path}")
        
        # Display first few rows
        print(f"\nFirst 5 rows:")
        pd.set_option('display.max_columns', None)
        pd.set_option('display.width', None)
        print(df.head())
        
        # Display basic statistics
        print(f"\nBasic statistics for key metrics:")
        key_metrics = ['AVG_DATA_SIZE_MB', 'AVG_COMPR_SIZE_MB', 'AVG_RATIO', 'MAX_DATA_SIZE_MB']
        available_metrics = [m for m in key_metrics if m in df.columns]
        if available_metrics:
            print(df[available_metrics].describe())
        
        # Show data distribution by benchmark and dump number
        print(f"\nData distribution:")
        print("Records per benchmark:")
        print(df['benchmark'].value_counts().sort_index())
        
        print("\nRecords per dump number:")
        print(df['dump_number'].value_counts().sort_index())
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()