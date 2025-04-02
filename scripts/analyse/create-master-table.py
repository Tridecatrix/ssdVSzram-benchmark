#!/bin/python3

# Create master table from JSON fio outputs, including both config param columns and metric columns.

# Main result collection script. Given a directory of results with some internal directory structure
# (all that matters is that each fio output is in a seperate directory within the resultsDir and are all
# called fio_out.txt, and the fio output is in JSON mode), make a master CSV table with columns 

# Note: it is also possible to probably do a one liner in bash that join together the terse output across
# CSV files since each one is meant to be CSV row. The initial reason I did not do this was a bad reason
# (I could not find the header line for the CSV format even though it was directly on the fio page), but
# after already writing this script I discovered there were in fact two good reasons:
# - Retaining human readability of the output for quick checking
# - (Frustratingly) the terse output does not include any config parameters/job option descriptions, while
#   the json output does


import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import json
import os
import sys
import argparse

# import analysis/analysislib.py
import analysislib as alib 

# ------------------------------------
# preamble
# ------------------------------------

parser = argparse.ArgumentParser(prog = "Create master table", 
                                 description = "Given directory containing data from a run of fio, create one large CSV " +
                                               "with columns for all config parameters as well as metric parameters")


parser.add_argument("-r", required=True, dest="resultsDir", help="Directory containing results from this experiment")
parser.add_argument("-o", dest="outputDir", help="Directory to save master table")

args = parser.parse_args()

resultsDir = args.resultsDir
outputDir = args.outputDir if args.outputDir != None else resultsDir

# ------------------------------------
# main
# ------------------------------------

configNames = [] # list of all config names (generated from names of subdirectories in resultsDir) 
configPaths = {} # dictionary mapping cnames in configNames to paths to their result files
allDataJson = {} # dictionary mapping cnames in configNames to the JSON dictionary loaded from that config's results
systemCSVs = {} # dictionary mapping cnames in configNames to a PD dataframe corresponding to its system data (measured by iostat)
diskstatCSVs = {} # dictionary mapping cnames in configNames to a PD dataframe corresponding to its diskstat data (measured by iostat and diskstat)

for subdirpath, subsubdirs, subfiles in os.walk(resultsDir):
    if "fio_out.txt" in subfiles:
        cpath = os.path.normpath(subdirpath)
        cname = cpath[len(resultsDir):].replace("\\", "‐")
        configNames.append(cname)
        configPaths[cname] = cpath

        try:
            with open(f"{cpath}/fio_out.txt") as datafile:
                allDataJson[cname] = json.load(datafile)
        except json.decoder.JSONDecodeError:
            print("ERROR: config " + cname + " has malformed fio_out.txt JSON; skipping")
            configNames.remove(cname)
            continue
        
        try:
            systemCSVs[cname] = pd.read_csv(f"{cpath}/system.csv", header=None, names=["metrics", "values"], index_col=0)
        except:
            print("ERROR: config " + cname + " has malformed system.csv")
            print("note: couldn't be bothered coding something graceful for this case so im gonna crash out lol")
            raise
            
        try:
            diskstatCSVs[cname] = pd.read_csv(f"{cpath}/diskstat.csv", header=None, names=["device", "metric", "value"])
        except:
            print("ERROR: config " + cname + " has malformed diskstat.csv")
            print("note: couldn't be bothered coding something graceful for this case so im gonna crash out lol")
            raise


# master table will have columns for params as well as columns for metrics
#
# dictionary keys below are the names of these columns as they will appear in the master table
# dictionary values are the name of the corresponding index in the JSON, seperated by colons to indicate nesting
#  - values of 'special' mean this value must be parsed specially (e.g. for device param, need to extract device name from the directory)
#
# param keys will be prefixed by 'c-' to specify they are part of the config
#
# metrics additionally include any metrics from systemCSV and diskstatCSV
params = {
    "bSize": "job options:bs",
    "ioengine": "job options:ioengine",
    "iodepth": "job options:iodepth", # note: this will be overrided for sync ioengines to 1
    "rw": "job options:rw",
    "nproc": "job options:numjobs",
    "device": "special",
    "direct": "job options:direct",
    "memlim": "special",
    "file": "special"
}
metrics = {
    "readBW_bytes": "read:bw_bytes",
    "writeBW_bytes": "write:bw_bytes",
    "avgreadlat_ns": "read:lat_ns:mean",
    "avgwritelat_ns": "write:lat_ns:mean"
} # TODO: add more metrics

paramDefaults = {
    "bSize": 4096,
    "iodepth": 1,
    "rw": "read",
    "nproc": 1,
    "direct": 0
}

# for the metrics, also create "human readable" columns that convert the number to appropriate units
formatfuncs = {
    "readBW_bytes": ("readBW", alib.format_size),
    "writeBW_bytes": ("writeBW", alib.format_size),
    "avgreadlat_ns": ("avgreadlat", alib.format_time),
    "avgwritelat_ns": ("avgwritelat", alib.format_time),
    "cmemlim": ("cmemlim_bytes", alib.unformat_size_1)
}

columns = {**{"c" + pname: ppath for pname, ppath in params.items()}, **metrics}

# lookup tables for 
# - device names from device mountpoints
# - device system names from device names (e.g. ssd = nvme0c0n1)

mntpointToDname = {
                    "mnt/ssd": "ssd", 
                    "zrammount": "zram-lzo",
                    "zrammnt0": "zram-lzo",
                    "zrammnt1": "zram-zstd",
                    "zrammnt2": "zram-lz4",
                    "tmpfs": "ram"
                }

dnameToSysname = {
    "ssd": "nvme0c0n1",
    "zram-lzo": "zram0",
    "zram-zstd": "zram1",
    "zram-lz4": "zram2",
    "ram": None # TODO: handle RAM correctly
}

# main table generation code below

mTable = []

for cname, cjson in allDataJson.items():
    mRow = {}

    cjson = cjson["jobs"][0]
    for colname, colpath in columns.items():
        if colpath == "special":

            if colname == "cdevice":
                target = cjson["job options"]["directory"] if "directory" in cjson["job options"] else cjson["job options"]["filename"]

                for mntpoint, dname in mntpointToDname.items():
                    if mntpoint in target:
                        value = dname
                        break
                else:
                    print("Unable to identify device given target " + target)
                    exit(1)
            
            if colname == "cmemlim":
                if "cgroup" in cjson["job options"] and "memlim" in cjson["job options"]["cgroup"]:
                    value = cjson["job options"]["cgroup"].split("/")[1]
                else:
                    value = "none"
            
            if colname == "cfile":
                if "filename" in cjson["job options"]:
                    value = cjson["job options"]["filename"].split("/")[-1]

                    # if it a heap dump, add seperate additional columns with the name of the benchmark
                    if (value.endswith("hprof")):
                        mRow["cdumpbc"] = value.split(".")[0].split("-")[0]
                        mRow["cdumpno"] = value.split(".")[0].split("-")[1]

                else:
                    value = "none"

        else:
            value = cjson

            for key in colpath.split(':'):
                try:
                    value = value[key]
                except KeyError:
                    value = paramDefaults[key]
                
        mRow[colname] = value

        # for columns that are in formatfuncs, also call the format function and add an extra column
        # with the value (this is to allow having the bytes and ns outputs in most appropriate units
        # for human readability)
        if colname in formatfuncs:
            if mRow[colname] == "none":
                continue

            newcolname = formatfuncs[colname][0]
            cfunc = formatfuncs[colname][1]
            mRow[newcolname] = cfunc(mRow[colname])
        
    # also add columns for the CPU util/system metrics
    for systemMetric in systemCSVs[cname].index:
        mRow[systemMetric[:-3] + "_perc"] = systemCSVs[cname]["values"][systemMetric]

    # and also add columns for the diskstat metrics
    dev = dnameToSysname[mRow["cdevice"]]
    for d in diskstatCSVs[cname].iterrows():
        if d[1]["device"] == dev:
            mRow[f"diskutil-{d[1]['metric']}"] = d[1]["value"]

    mTable.append(mRow)

# finally, output table to CSV
mTable = pd.DataFrame(mTable)
mTable.to_csv(f"{outputDir}/master.csv")