#!/usr/bin/env python3
"""
Consolidate ZRAM compression data from multiple benchmarks and devices into a master table.

This script reads zram.csv files from each benchmark/device combination and creates
a consolidated pandas DataFrame with all metrics.
"""

import pandas as pd
import os
import sys
from pathlib import Path


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


def consolidate_zram_data(data_dir):
    """
    Consolidate all zram.csv files from the given data directory.
    
    Args:
        data_dir (str): Path to the data directory containing benchmark subdirs
        
    Returns:
        pd.DataFrame: Consolidated dataframe with all metrics
    """
    all_data = []
    
    data_path = Path(data_dir)
    if not data_path.exists():
        raise FileNotFoundError(f"Data directory not found: {data_dir}")
    
    # Get all benchmark directories
    benchmark_dirs = [d for d in data_path.iterdir() if d.is_dir()]
    
    for benchmark_dir in benchmark_dirs:
        benchmark_name = benchmark_dir.name
        
        # Get all zram device directories (zram0, zram1, zram2, etc.)
        device_dirs = [d for d in benchmark_dir.iterdir() 
                      if d.is_dir() and d.name.startswith('zram')]
        
        for device_dir in device_dirs:
            device_name = device_dir.name
            zram_csv_path = device_dir / 'zram.csv'
            
            metrics = parse_zram_csv(zram_csv_path)
            
            if metrics is not None:
                # Add identifying columns
                metrics['benchmark'] = benchmark_name
                metrics['device'] = device_name
                all_data.append(metrics)
                print(f"Loaded data for {benchmark_name}/{device_name}")
            else:
                print(f"Warning: No data found for {benchmark_name}/{device_name}")
    
    if not all_data:
        raise ValueError("No zram.csv files found in the data directory")
    
    # Create DataFrame
    df = pd.DataFrame(all_data)
    
    # Reorder columns to put identifiers first
    identifier_cols = ['benchmark', 'device']
    metric_cols = [col for col in df.columns if col not in identifier_cols]
    df = df[identifier_cols + sorted(metric_cols)]
    
    return df


def main():
    if len(sys.argv) != 2:
        print("Usage: python consolidate_zram_data.py <data_directory>")
        print("Example: python consolidate_zram_data.py ../data/2025-10-21-time-17-01-56-jvmheap-compression")
        sys.exit(1)
    
    data_dir = sys.argv[1]
    
    try:
        print(f"Consolidating ZRAM data from: {data_dir}")
        df = consolidate_zram_data(data_dir)
        
        print(f"\nConsolidated {len(df)} records from {df['benchmark'].nunique()} benchmarks "
              f"and {df['device'].nunique()} devices")
        
        # Display summary
        print(f"\nBenchmarks: {sorted(df['benchmark'].unique())}")
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
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()