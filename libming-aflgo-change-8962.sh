#!/bin/bash

set -euo pipefail

cd libming-CVE-2018-8962/ 

mkdir obj-aflgo-change; mkdir obj-aflgo-change/temp

export DIST_DIR=$PWD/obj-normal/util/tmp
export CC=$AFLGO/instrument/aflgo-clang; export CXX=$AFLGO/instrument/aflgo-clang++
export LDFLAGS=-lpthread

cd obj-aflgo-change;

CFLAGS="-fcommon -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt"  ../configure --disable-freetype --disable-shared --prefix=`pwd`
make clean
make
