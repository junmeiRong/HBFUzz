#!/bin/bash

set -euo pipefail

# Variables
REPO_URL="https://github.com/google/guetzli.git"
REPO_DIR="guetzli-2017-3-30"
CHECKOUT_COMMIT="9afd0bbb7db0bd3a50226845f0f6c36f14933b6b"

SYMCC_DIR="/root/symcc/build-qsym/symcc"
SYMXX_DIR="/root/symcc/build-qsym/sym++"
SVF_TOOL="/root/svf-tool/src/svf-tool"
AFLGO_DIR="/root/aflgo"
export SYMCC_REGULAR_LIBCXX=yes

# Clone and checkout the specific commit
git clone $REPO_URL obj-normal
cd obj-normal
git checkout $CHECKOUT_COMMIT

export LLVM_COMPILER=clang
CC=wllvm CXX=wllvm++ CFLAGS="-g -O0" CXXFLAGS="-g -O0" make -j32

cd bin/Release/
extract-bc guetzli
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR


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

echo 'output_image.cc:398' > $TMP_DIR/target.txt

# Run SVF tool
$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./guetzli.bc

cd ../../..
git clone $REPO_URL obj-symcc
cd obj-symcc
git checkout $CHECKOUT_COMMIT

CC=~/symcc/build-qsym/symcc  CXX=~/symcc/build-qsym/sym++ CFLAGS="-g -O0 -mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt" CXXFLAGS="-g -O0 -mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt" make -j32

cd ..
git clone $REPO_URL obj-aflgo-change
cd obj-aflgo-change
git checkout $CHECKOUT_COMMIT

CC=$AFLGO_DIR/instrument/aflgo-clang CXX=$AFLGO_DIR/instrument/aflgo-clang++ CFLAGS="-O0 -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-O0 -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" make

# Create input directory and seed file
cd ..

mkdir -p in
cp ~/aflgo/examples/fuzzer-test-suite/guetzli-2017-3-30/seeds/* ./in/

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz-gue -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/bin/Release/guetzli @@ /tmp
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz-gue -n symcc -- ./obj-symcc/bin/Release/guetzli @@ /tmp