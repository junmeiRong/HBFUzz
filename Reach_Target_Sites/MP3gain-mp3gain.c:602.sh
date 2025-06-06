#!/bin/bash

set -euo pipefail

# Variables
REPO_URL="https://gitee.com/lujun-jie/mp3gain.git"
REPO_DIR="mp3gain"
CHECKOUT_COMMIT="mp3gain-1.5"

wget wget https://sourceforge.net/projects/mp3gain/files/mp3gain/1.5.2/mp3gain-1_5_2-src.zip/download

unzip download -d ./MP3gain-apetag.c:341

cd MP3gain-apetag.c:341

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

export LLVM_COMPILER=clang
make CC=wllvm CFLAGS="-g -O0"

# Generate bitcode and prepare files for SVF analysis
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc mp3gain
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

echo 'mp3gain.c:602' > $TMP_DIR/target.txt

$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./mp3gain.bc

cd ..
unzip download -d ./MP3gain-apetag.c:341-symcc

cd MP3gain-apetag.c:341-symcc
# Compile symcc build
make CC=$SYMCC_DIR CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g -O0"

cd ..
unzip download -d ./MP3gain-apetag.c:341-aflgo

cd MP3gain-apetag.c:341-aflgo
make CC=$AFLGO_DIR/instrument/aflgo-clang CFLAGS="-distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt -O0 -g"

# Create input directory and seed file
cd ..
mkdir -p in
cp ~/seeds/general_evaluation/mp3/0.mp3 in/

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz690 -m none -z exp -c 45m -i in -o out -- ./MP3gain-mp3gain.c\:602-aflgo/mp3gain @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz690 -n symcc -- ./MP3gain-mp3gain.c\:602-symcc/mp3gain @@