#!/usr/bin/bash
PYTHONPATH=`pwd`:$PYTHONPATH nix-shell --run "python main.py $*"