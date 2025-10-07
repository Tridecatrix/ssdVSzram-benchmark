# Common functions for data analysis, including graph creation and number processing.
# Mainly created these when existing libraries don't have what I want for some reason.

# Commands to set up running this library from directory root:
'''
import pandas as pd
import pandasql as pdsql
import sys

sys.path.append("scripts/analyse")
import analysislib as alib

sq = lambda q: pdsql.sqldf(q, globals())
sqflat = lambda q: alib.flatten(pdsql.sqldf(q, globals()).values.tolist())
'''

import numpy as np
import pandas as pd
import statistics as st
import os, sys
import matplotlib.pyplot as plt
import pandasql as pdsql

# ------------------------------
# PandaSQL
# ------------------------------

# Note: the below two definitions unfortunately do not work because globals()
# only includes the global variables within this library, not any program this library
# may be imported into, so just copy these two into script where you plan to use them.
# The dependent library import pdsql is included for convenience.
''' 
import pandasql as pdsql
import analysislib as alib

sq = lambda q: pdsql.sqldf(q, globals())
sqflat = lambda q: alib.flatten(pdsql.sqldf(q, globals()).values.tolist())
'''

# ------------------------------
# Numerical
# ------------------------------

# Converts size to a string specifying size with most appropriate suffix
# written by chatgpt lol
def format_size(size):
    suffixes = ['B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
    i = 0
    while size >= 1024 and i < len(suffixes) - 1:
        size /= 1024.0
        i += 1
    return f"{size:.1f} {suffixes[i]}"

# this is specifically for a size string of the format <number>K/M/G/T
# such as the format used for memory limit in memlim as well as by zramctl in its size outputs
def unformat_size_1(size_string):
    suffixes=["K", "M", "G", "T"]
    return float(size_string[:-1]) * pow(1024, 1+suffixes.index(size_string[-1]))

# Converts time (in n) to a string specifying time with most appropriate suffix
# written by chatgpt lol
def format_time(time_in_ns):
    # Time units
    units = ['ns', 'µs', 'ms', 's']
    
    # Start with nanoseconds
    i = 0
    
    # Convert time to the appropriate unit
    while time_in_ns >= 1000 and i < len(units) - 1:
        time_in_ns /= 1000.0
        i += 1
    
    # Format the result
    return f"{time_in_ns:.1f} {units[i]}"

# ------------------------------
# Graphical
# ------------------------------

# Generic function for making a grouped bar plot.
#
# Required args: 
# xs - lists of labels on x axis
# yss - lists of lists of values on y axis. Each list corresponds to one series.
#       so if yss = [[1, 2, 3], [4, 5, 6]], two series would be plotted with 3 values on the x
#       axis, and [1, 2, 3] plotted in one color while [4, 5, 6] is plotted in another.
#
# Optional args:
# xlabel - x axis label
# ylabel - y axis label
# title - graph title
# figsize - two-element list giving the width and height of the plot
# l - normalised width of each set of bars. 1 means each set is touching the sets to either side and is not recommended.
# d - normalised width of each sub-bar in a set, i.e. the bars for each series in a set. setting this to l/k causes
#     the sub-bars to be touching; any greater value than l/k is not recommended.
# labels - legend labels for each series
# show - whether to call plt.show() before returning. useful to provide false if user wants to add more appearance options
#        seperate to the function call
# colors - colors for each series plotted
# xpos - specifies positions on the x axis where each set of bars is, as indexes starting from 0.
#        defaults to range(0, len(xs)). expected use case is if using multiple calls to this function, e.g. some bars are different color
#        e.g. if you want some sets of bars to be a different color, but there are some issues with this that haven't
#        been ironed out yet, e.g. how would the legend work for something like this?
def grouped_barplot(xs, yss, xlabel=None, ylabel=None, title=None, figsize=[8, 4], 
                   l=0.7, d=None, labels=None, show=True, colors=None, xpos=[], 
                   fontsize=10, create_new_figure=True, ax=None):
    
    # Use provided axes object (could be BrokenAxes) or create new figure
    if ax is None:
        if create_new_figure:
            plt.figure(figsize=figsize)
        ax = plt  # Use plt for normal plotting
    
    # Check if we're using plt or an actual axes object
    is_plt = (ax == plt)
    
    # Use ax instead of plt for all plotting commands
    if is_plt:
        plt.grid(which="major", axis="y", zorder=0)
    else:
        ax.grid(which="major", axis="y", zorder=0)
    
    k = len(yss)
    w = l/k
    if d == None:
        d = w
    
    if len(xpos) == 0:
        xpos = np.arange(len(xs))
        
    if (len(yss) > 0):
        assert(len(xpos) == len(yss[0]))
        
    for i, ys in enumerate(yss):
        if labels == None:
            if colors == None:
                if is_plt:
                    plt.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3)
                else:
                    ax.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3)
            else:
                if is_plt:
                    plt.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3, color=colors[i])
                else:
                    ax.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3, color=colors[i])
        else:
            if colors == None:
                if is_plt:
                    plt.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3, label=labels[i])
                else:
                    ax.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3, label=labels[i])
            else:
                if is_plt:
                    plt.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3, label=labels[i], color=colors[i])
                else:
                    ax.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3, label=labels[i], color=colors[i])
    
    # Handle xticks differently for different axes types
    if is_plt:
        plt.xticks(np.arange(len(xs)), xs)
    elif hasattr(ax, 'set_xticks'):  # BrokenAxes or regular axes object
        ax.set_xticks(np.arange(len(xs)), xs)
        # ax.set_xticklabels(xs)
    else:  # Some other axes type
        ax.xticks(np.arange(len(xs)), xs)
    
    # Handle labels and titles
    if xlabel != None:
        if is_plt:
            plt.xlabel(xlabel)
        else:
            ax.set_xlabel(xlabel)
    if ylabel != None:
        if is_plt:
            plt.ylabel(ylabel)
        else:
            ax.set_ylabel(ylabel)
    if labels != None: 
        if is_plt:
            plt.legend()
        else:
            ax.legend()
    if title != None:
        if is_plt:
            plt.title(title)
        else:
            ax.set_title(title)
    
    if show and is_plt:
        plt.show()

# Helper function for grouped_barplot_flat (see below)
def unflatten_ys(xs, ys, roworder=True):
    rowLength = len(xs)
    colLength = len(ys) // len(xs)

    if roworder:
        # e.g. xs = [row1, row2], ys = [1, 2, 3, 4, 5, 6]
        # then it would group as yss = [[1,2,3], [4,5,6]]
        yss = [ys[rowLength*i : rowLength*(i+1)] for i in range(colLength)]
    else:
        # e.g. xs = [row1, row2], ys = [1, 2, 3, 4, 5, 6]
        # then it would group as yss = [[1,3,5], [2,4,6]]
        # i.e. ys is in column order
        yss = [ys[i : : rowLength] for i in range(colLength)]
    
    return yss

# Version of grouped barplot where yss is a flattened list, and the grouping is inferred
def grouped_barplot_flat(xs, ys, roworder=True, **kwargs):
    yss = unflatten_ys(xs, ys, roworder)
    grouped_barplot(xs, yss, **kwargs)

# Function created by AI; for plotting CPU utilisation stacks for groups of configurations.
# The default parameters fit the tables used for 2025 honours project.
# 
# Plots a stacked bar chart of CPU utilization metrics grouped by configuration and RWTYPE.
# Filters for ioengine and numjobs as specified.
# Bars are sorted by the grouping col and then config col.
# Adds spacing between config groups.
def stacked_barplot_cpu_util(df, grouping_col='cdevice', config_col='crw', util_cols=['SYS_UTIL_perc', 'IOW_UTIL_perc', 'USR_UTIL_perc', 'IDL_UTIL_perc'],
                             ioengine_val='mmap', numjobs_val=32, figsize=(10, 6), colors=None, show=True, group_gap=1):
    
    # Filter DataFrame
    df_filtered = df[(df['cioengine'] == ioengine_val) & (df['cnproc'] == numjobs_val)].copy()
    
    # Sort by grouping then config 
    df_filtered.sort_values([grouping_col, config_col], inplace=True)
    
    # Group by grouping column
    grouped = df_filtered.groupby(grouping_col)
    group_labels = []
    util_data = [[] for _ in util_cols]
    
    for config, group in grouped:
        for _, row in group.iterrows():
            group_labels.append(f"{row[grouping_col]} - {row[config_col]}")
            for i, col in enumerate(util_cols):
                util_data[i].append(row[col])
        # Add gap
        for _ in range(group_gap):
            group_labels.append("")
            for i in range(len(util_cols)):
                util_data[i].append(0)
    # Remove trailing gap
    while group_labels and group_labels[-1] == "":
        group_labels.pop()
        for i in range(len(util_cols)):
            util_data[i].pop()
    
    # Set colors if not provided
    if colors is None:
        colors = default_colors[:len(util_cols)]
    
    # Plot
    plt.figure(figsize=figsize)
    bottom = np.zeros(len(group_labels))
    for i, (col, color) in enumerate(zip(util_cols, colors)):
        plt.bar(group_labels, util_data[i], bottom=bottom, label=col, color=color)
        bottom += util_data[i]
    
    plt.xlabel(f'{grouping_col} - {config_col}')
    plt.ylabel('Utilization (%)')
    plt.title(f'CPU Utilization Breakdown (ioengine={ioengine_val}, numjobs={numjobs_val})')
    plt.legend()
    plt.xticks(rotation=30, ha='right')
    plt.tight_layout()
    if show:
        plt.show()

# ------------------------------
# Colors
# ------------------------------

# Given a hex color, adjust its brightness
def adjust_lightness(color, amount=0.5):
    import matplotlib.colors as mc
    import colorsys
    try:
        c = mc.cnames[color]
    except:
        c = color
    c = colorsys.rgb_to_hls(*mc.to_rgb(c))
    return colorsys.hls_to_rgb(c[0], max(0, min(1, amount * c[1])), c[2])

default_colors = plt.rcParams['axes.prop_cycle'].by_key()['color']

pastel_colors = [
    "#AEC6CF",  # pastel blue
    "#FFB347",  # pastel orange
    "#B39EB5",  # pastel purple
    "#77DD77",  # pastel green
    "#FFD1DC",  # pastel pink
    "#FFFACD",  # pastel yellow
    "#CFCFC4",  # pastel gray
    "#F49AC2",  # pastel magenta
    "#B0E0E6",  # pastel turquoise
    "#E6E6FA",  # pastel lavender
]

# -----------------------------
# Misc
# -----------------------------

def flatten(xss):
    return [x for xs in xss for x in xs]