#!/bin/bash

set -euo pipefail

# Variables
REPO_URL="https://gitee.com/xwiron/mjs.git"
REPO_DIR="mjs-issues-59"
CHECKOUT_COMMIT="d6c06a6"

SYMCC_DIR="/root/symcc/build-qsym/symcc"
SVF_TOOL="/root/svf-tool/src/svf-tool"
AFLGO_DIR="/root/aflgo"

# Clone and checkout the specific commit
git clone $REPO_URL $REPO_DIR
cd $REPO_DIR
git checkout $CHECKOUT_COMMIT

# Create necessary directories
mkdir -p obj-normal obj-symcc obj-aflgo-change

# Compile normal build with wllvm
cd ./obj-normal
export LLVM_COMPILER=clang
wllvm -DMJS_MAIN ../mjs.c -g -ldl -o mjs-bin

# Generate bitcode and prepare files for SVF analysis
TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc mjs-bin
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

echo 'mjs.c:8617' > $TMP_DIR/target.txt

# Run SVF tool
$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./mjs-bin.bc

# Compile symcc build
cd ../obj-symcc
$SYMCC_DIR -mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -DMJS_MAIN ../mjs.c -g  -ldl -o mjs-bin

cd ../obj-aflgo-change
$AFLGO_DIR/instrument/aflgo-clang -DMJS_MAIN -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt ../mjs.c -ldl -g -o mjs-bin

# Create input directory and seed file
cd ..
mkdir -p in
cp $AFLGO_DIR/afl-2.57b/testcases/others/js/small_script.js ./in

# $AFLGO/afl-2.57b/afl-fuzz -m none -z exp -c 45m -i in -o out ../mjs-bin -f @@
