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

mTable = []

for rDir in filter(lambda p: os.path.isdir(os.path.join(resultsDir, p)), os.listdir(resultsDir)):
    before = pd.read_csv(f"{resultsDir}/{rDir}/before", sep="\s+", index_col=0)
    after = pd.read_csv(f"{resultsDir}/{rDir}/after", sep="\s+", index_col=0)

    for dev in before.index:
        mRow = {}

        mRow["benchmark"] = rDir.split("-")[0]
        mRow["dumpNo"] = rDir.split("-")[1]
        mRow["compression_alg"] = before["ALGORITHM"][dev]

        diff = lambda k: alib.unformat_size_1(after[k][dev]) - alib.unformat_size_1(before[k][dev])
        mRow["data_bytes"] = diff("DATA")
        mRow["compressed_bytes"] = diff("COMPR")
        mRow["total_bytes"] = diff("TOTAL")
        
        mRow["compr_ratio"] = mRow["data_bytes"] / mRow["total_bytes"] if mRow["total_bytes"] > 0 else 1
    
        mTable.append(mRow)

# finally, output table to CSV
mTable = pd.DataFrame(mTable)
mTable.to_csv(f"{outputDir}/master.csv")