# Preprocessing Libraries

## Overview

This is a set of libraries written to support preprocessing of ephys data
collected by Thilo's lab.

The library routines are intended to cover the following tasks:
* Reading experiment metadata.
* Reading raw ephys data, game data, and gaze data.
* Segmenting experiment data into per-trial records.
* Performing artifact rejection on ephys data.
* Assisting bad channel detection for ephys data.
* Producing per-trial records with derived ephys signals (MUA, LFP, etc).

Not presently implemented but within the scope of this project:
* Performing filtering and cleanup of gaze data.
* Saving per-trial gaze data in Field Trip format.

The idea is to make it easy and fast to write pre-processing code so that
effort may be focused on analysis of ephys and behavior data after
pre-processing.


## Documentation Folders

The `manuals` folder contains PDF documentation files for this project.

The `manual-src` directory contains scripts and source for rebuilding the
documentation. Use `make -C manual-src` to rebuild the `manuals` files.

Various demo scripts are provided. The folders with these scripts have
their own README files.


## Library Folders

Libraries are provided as subfolders in the `libraries` folder. With that
folder on path, call `addPathsExpPreproc` to add sub-folders.

Library folders are:

_(Documentation NYI.)_



## Sample Code Folders

Sample code suitable for reference is in the following folders. Most
folders also have a README file describing the sample code.

_(NYI)_


_(This is the end of the file.)_
