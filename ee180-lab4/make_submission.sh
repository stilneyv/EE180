#!/bin/sh

DIR=lab4_submission

rm -rf $DIR $DIR.tar.gz
mkdir -p $DIR
cp README $DIR
cp -R hw/fpga.img $DIR
cp -R hw/hdl/verilog/sobel $DIR
cp -R sim/tests $DIR
tar -czf $DIR.tar.gz $DIR
rm -rf $DIR
