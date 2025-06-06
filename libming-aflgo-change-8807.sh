#!/bin/bash

set -euo pipefail

# git clone https://github.com/libming/libming.git libming-CVE-2018-8962
cd libming-CVE-2018-8807/ 
# git checkout b72cc2f # version 0.4.8
mkdir obj-aflgo-change; mkdir obj-aflgo-change/temp
# export TMP_DIR=$PWD/obj-aflgo/temp
export DIST_DIR=$PWD/obj-normal/util/tmp
export CC=$AFLGO/instrument/aflgo-clang; export CXX=$AFLGO/instrument/aflgo-clang++
export LDFLAGS=-lpthread
# export ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
# echo $'decompile.c:349' > $TMP_DIR/BBtargets.txt
# ./autogen.sh;
cd obj-aflgo-change;
# CFLAGS="-fcommon $ADDITIONAL" CXXFLAGS="$ADDITIONAL" ../configure --disable-freetype --disable-shared --prefix=`pwd`
# make clean; make
# cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
# cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
# cd util; $AFLGO/distance/gen_distance_orig.sh $PWD $TMP_DIR swftophp
# cd -; 
# CFLAGS="-fcommon -distance=$TMP_DIR/distance.cfg.txt" CXXFLAGS="-distance=$TMP_DIR/distance.cfg.txt" ../configure --disable-freetype --disable-shared --prefix=`pwd`
# make clean; make

CFLAGS="-fcommon -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt"  ../configure --disable-freetype --disable-shared --prefix=`pwd`
make clean; make
# mkdir in; wget -P in http://condor.depaul.edu/sjost/hci430/flash-examples/swf/bumble-bee1.swf
# $AFLGO/afl-2.57b/afl-fuzz -m none -z exp -c 45m -i in -o out ./util/swftophp @@

# For "-fcommon" in CFLAGS please see
#  - https://github.com/libming/libming/issues/55
#  - https://github.com/libming/libming/issues/199
#  - https://github.com/squaresLab/security-repair-benchmarks/issues/19
