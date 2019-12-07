#!/usr/bin/env bash

# Command to compare the output of the C and MIPS implementations of mergesort.
# Written by Chris Copeland (chrisnc@stanford.edu)

# usage: ./test.sh inputfile

# (make sure to run "chmod +x test.sh" first)

# attempt to build the executable if it does not exist
if [ ! -e "mergesort"  ]
then
	make
fi

diff <(./mergesort < $1 | tail -n 1) <(spim -file mergesort.s < $1 | tail -n 1)
