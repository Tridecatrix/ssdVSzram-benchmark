#!/bin/python3

# Main result collection script. Given a directory of results

import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import json
import os
import argparse

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
            print("ERROR: config " + cname + " has malformed JSON; skipping")
            configNames.remove(cname)


# master table will have columns for params as well as columns for metrics
#
# dictionary keys below are the names of these columns as they will appear in the master table
# dictionary values are the name of the corresponding index in the JSON, seperated by colons to indicate nesting
#  - values of 'special' mean this value must be parsed specially (e.g. for device param, need to extract device name from the directory)
#
# param keys will be prefixed by 'c-' to specify they are part of the config
params = {
    "bSize": "job options:bs",
    "ioengine": "job options:ioengine",
    "iodepth": "job options:iodepth", # note: this will be overrided for sync ioengines to 1
    "rw": "job options:rw",
    "nproc": "job options:numjobs",
    "device": "special"
}
metrics = {
    "readBW": "read:bw",
    "writeBW": "write:bw",
    "avgreadlat": "read:lat_ns:mean",
    "avgwritelat": "write:lat_ns:mean"
} # TODO: add more metrics

paramDefaults = {
    "bSize": 4096,
    "iodepth": 1,
    "rw": "read",
    "nproc": 1
}

columns = {**{"c" + pname: ppath for pname, ppath in params.items()}, **metrics}

# main table generation code below

mTable = []

for cname, cjson in allDataJson.items():
    mRow = {}

    cjson = cjson["jobs"][0]
    for colname, colpath in columns.items():
        value = cjson

        if colpath == "special":
            if colname == "cdevice":
                directory = cjson["job options"]["directory"]
                if "zram" in directory:
                    value = "zram"
                elif "ssd" in directory:
                    value = "ssd"
        else:
            for key in colpath.split(':'):
                try:
                    value = value[key]
                except KeyError:
                    value = paramDefaults[key]
                
        mRow[colname] = value
        
    mTable.append(mRow)

# finally, output table to CSV
mTable = pd.DataFrame(mTable)
mTable.to_csv(f"{outputDir}/master.csv")