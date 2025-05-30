#!/bin/bash

set -euo pipefail

# Variables
REPO_URL="https://github.com/Exiv2/exiv2.git"
REPO_DIR="exiv2"
CHECKOUT_COMMIT="v0.26"

git clone https://github.com/Exiv2/exiv2.git exiv2-XMPMeta-Parse.cpp:1037
cd  exiv2-XMPMeta-Parse.cpp:1037
git checkout v0.26

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

mkdir -p obj-normal obj-symcc obj-aflgo-change

cd ./obj-normal
export LLVM_COMPILER=clang
cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER="wllvm" -DCMAKE_C_FLAGS="-O0 -g" -DCMAKE_CXX_COMPILER="wllvm++" -DCMAKE_CXX_FLAGS="-O0 -g" -S .. -DCMAKE_BUILD_TYPE=Release
make -j32

# Generate bitcode and prepare files for SVF analysis
cd bin
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc exiv2
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

echo 'stl_algo.h:161' > $TMP_DIR/target.txt

$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./exiv2.bc

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

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz182 -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/exiv2 . @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz182 -n symcc -- ./obj-symcc/exiv2 . @@