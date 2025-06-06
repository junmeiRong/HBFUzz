#!/bin/bash

git clone https://gitlab.com/libtiff/libtiff.git tiffsplit-tif_dir.c:566
cd  tiffsplit-tif_dir.c:566
git checkout v3.9.7

autoreconf -i  

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"
export SYMCC_REGULAR_LIBCXX=yes

mkdir -p obj-normal obj-symcc obj-aflgo-change

cd ./obj-normal
export LLVM_COMPILER=clang
CC=wllvm CXX=wllvm++ ../configure --disable-shared  CXXFLAGS="-g -O0" CFLAGS="-g -O0"
make -j32

# Generate bitcode and prepare files for SVF analysis
cd tools
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc tiffsplit
mkdir $TMP_DIR
mkdir $TMP_DIR/results
touch $TMP_DIR/cdbb.txt
touch $TMP_DIR/cdbb.txt
touch $TMP_DIR/cdbb2.txt
touch $TMP_DIR/ddbb.txt
touch $TMP_DIR/ddbb2.txt

export SYMCC_OUTPUT_DIR=$TMP_DIR/results
export SYMCC_SVF_CDBB_FILE=$TMP_DIR/cdbb2.txt
export SYMCC_SVF_DDBB_FILE=$TMP_DIR/ddbb2.txt
export BR_FILE=$TMP_DIR/brs.txt

echo 'tif_strip.c:154' > $TMP_DIR/target.txt

$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./tiffsplit.bc

# Compile symcc build
cd ../../obj-symcc
CC=$SYMCC_DIR CXX=$SYMXX_DIR ../configure --disable-shared CXXFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g -O0" CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g -O0"
make -j32

cd ../obj-aflgo-change
CC=$AFLGO_DIR/instrument/aflgo-clang CXX=$AFLGO_DIR/instrument/aflgo-clang++ ../configure --disable-shared CXXFLAGS=" -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt -O0" CFLAGS="-g -Wno-error -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt -O0"
make -j32

# Create input directory and seed file
cd ..
mkdir -p in
cp ~/aflgo/afl-2.57b/testcases/images/tiff/not_kitty.tiff in

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz154 -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/tools/tiffsplit @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz154 -n symcc -- ./obj-symcc/tools/tiffsplit @@