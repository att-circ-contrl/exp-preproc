#!/bin/bash

if [ ! -d plots ]
then
  echo "Creating plots directory."
  mkdir plots
fi

if [ ! -d data-sessions ]
then
  echo "Creating per-session cache directory."
  mkdir data-sessions
fi

if [ ! -d data-trials ]
then
  echo "Creating per-trial cache directory."
  mkdir data-trials
fi

# This is the end of the file.
