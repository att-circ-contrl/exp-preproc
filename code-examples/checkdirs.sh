#!/bin/bash

if [ ! -d plots ]
then
  echo "Creating plots directory."
  mkdir plots
fi

if [ ! -d data-sessions ]
then
  echo "Creating per-session output directory."
  mkdir data-sessions
fi

if [ ! -d data-trials ]
then
  echo "Creating per-trial output directory."
  mkdir data-trials
fi

if [ ! -d data-epoched ]
then
  echo "Creating epoched data directory."
  mkdir data-epoched
fi

# This is the end of the file.
