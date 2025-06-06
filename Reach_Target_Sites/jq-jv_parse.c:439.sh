#!/bin/bash

set -euo pipefail

# Variables
REPO_URL="https://gitee.com/lujun-jie/jq.git"
REPO_DIR="jq"
CHECKOUT_COMMIT="jq-1.5"

git clone https://gitee.com/lujun-jie/jq.git jq
cd  jq
git checkout jq-1.5

autoreconf -i  

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

mkdir -p obj-normal obj-symcc obj-aflgo-change

cd ./obj-normal
export LLVM_COMPILER=clang
CC=wllvm CXX=wllvm++ ../configure --disable-shared CXXFLAGS="-g -O0" CFLAGS="-g -O0"
make -j32

# Generate bitcode and prepare files for SVF analysis
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc jq
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

echo 'jv_parse.c:439' > $TMP_DIR/target.txt

$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./jq.bc

# Compile symcc build
cd ../obj-symcc
CC=$SYMCC_DIR CXX=$SYMXX_DIR ../configure --disable-shared --prefix=$PWD CXXFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -O0" CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -O0"
make -j32

cd ../obj-aflgo-change
CC=$AFLGO_DIR/instrument/aflgo-clang CXX=$AFLGO_DIR/instrument/aflgo-clang++ ../configure --disable-shared --prefix=$PWD CXXFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -Wno-error -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt -O0" CFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt -O0"
make -j32

# Create input directory and seed file
cd ..
mkdir -p in
cp ~/seeds/general_evaluation/json/* in

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz182 -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/jq . @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz182 -n symcc -- ./obj-symcc/jq . @@