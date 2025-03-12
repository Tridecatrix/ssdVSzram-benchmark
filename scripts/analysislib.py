# Common functions for data analysis, including graph creation and number processing.
# Mainly created these when existing libraries don't have what I want for some reason.

import numpy as np
import pandas as pd
import statistics as st
import os, sys
import matplotlib.pyplot as plt

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

# this is specifically for the size string included in the memlim parameter (the memory.max parameter
# passed to cgroup)
def unformat_size_memlim(size_string):
    suffixes=["K", "M", "G"]
    return int(size_string[:-1]) * pow(1024, 1+suffixes.index(size_string[-1]))

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
def grouped_barplot(xs, yss, xlabel=None, ylabel=None, title=None, figsize=[8, 4], l=0.7, d=None, labels=None, show=True, colors=None, xpos=[]):
    plt.figure(figsize=figsize)
    
    plt.grid(which="major", axis="y", zorder=0)

    k = len(yss) # no of bars
    w = l/k
    if d == None: # d = 0 means nothing was specified/default was chosen
        d = w # width of each sub-bar

    if len(xpos) == 0:
        xpos = np.arange(len(xs))
        
    if (len(yss) > 0):
        assert(len(xpos) == len(yss[0]))
        
    for i, ys in enumerate(yss):
        if labels == None:
            if colors == None:
                plt.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3)
            else:
                plt.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3, color=colors[i])
        else:
            if colors == None:
                plt.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3, label=labels[i])
            else:
                plt.bar(xpos - l/2 + w/2 + i*w, ys, d, zorder=3, label=labels[i], color=colors[i])
            
    plt.xticks(np.arange(len(xs)), xs)
    if xlabel != None:
        plt.xlabel(xlabel)
    if ylabel != None:
        plt.ylabel(ylabel)
    if labels != None: 
        plt.legend()
    if title != None:
        plt.title(title)

    if show:
        plt.show()

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

