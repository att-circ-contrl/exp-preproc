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

Library sub-folders are:

* `lib-exppreproc-iter` --
High-level entry-point function that iterates through sessions, probes, and
trials, and helper functions that perform various preprocessing tasks.

_(Ported ExpUtils subfolders NYI.)_

This library requires the following other libraries:
* Field Trip
	This is at: <https://github.com/fieldtrip/fieldtrip>
* Open Ephys's "analysis tools" library.
	This is at: <https://github.com/open-ephys/analysis-tools>
* The `npy-matlab` library (needed by Open Ephys's library; it comes with it).
* The `LoopUtil` library from our lab's GitHub page.
	This is at: <https://github.com/att-circ-contrl/LoopUtil>
* The `exp-utils-cjt` library from our lab's GitHub page.
	This is at: <https://github.com/att-circ-contrl/exp-utils-cjt>


## Sample Code Folder

Sample code suitable for reference is in the `code-examples` folder. This
includes the following files:

* `do_config.m` specifies where to find the raw ephys datasets, and specifies
configuration information for each of the preprocessing operations.
* `do_sessionmeta.m` reads ephys headers and auxiliary files (game files),
builds event lists and trial definitions, and saves all of this metadata in
a consolidated format.
* `do_preproc.m` reads the raw ephys datasets, performs several preprocessing
steps, and saves the results of each step in Field Trip format. Preprocessing
steps are segmentation into trials, artifact removal, bad channel detection,
and filtering/rectification/downsampling to produce derived signals.
* `do_epoch.m` reads per-trial Field Trip files, time-aligns them to desired
events, and crops them to a region of interest around these events.
* `do_manual_badchans.m` provides manual lists of bad channels. These can be
used instead of automatically-detected bad channels (by changing a flag in
`do_config.m`).

To run the demo code, make sure that the configuration file points to the
FLToken dataset, make sure that all needed libraries are on Matlab's path,
and from a Linux or MacOS command line type "make allclean", "make session",
"make preproc", and "make epoch".

Two steps will produce plots: Pre-processing will produce bad channel
analysis plots, and epoching will produce strip-charts of timelocked data
and per-trial waveform data (for a small number of trials). Type "make
gallery" to build a `gallery.html` file in the plot folder showing these
plots.

The `make` command should work from a command terminal under Linux and
MacOS. To run the scripts from the Matlab GUI instead, manually make several
sub-folders (`data-sessions`, `data-trials`, `data-epoched`, `plots`), and
then run the `do_sessionmeta.m`, `do_preproc.m`, and `do_epoch.m` scripts to
perform the preprocessing steps.


_(This is the end of the file.)_
