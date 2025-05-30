#!/bin/bash

set -euo pipefail

# Variables
REPO_URL="https://github.com/google/boringssl.git"
REPO_DIR="boringssl-2016-02-12"
CHECKOUT_COMMIT="894a47df2423f0d2b6be57e6d90f2bea88213382"

SYMCC_DIR="/root/symcc/build-qsym/symcc"
SYMXX_DIR="/root/symcc/build-qsym/sym++"
SVF_TOOL="/root/svf-tool/src/svf-tool"
AFLGO_DIR="/root/aflgo"
export SYMCC_REGULAR_LIBCXX=yes
# Clone and checkout the specific commit
git clone $REPO_URL $REPO_DIR
cd $REPO_DIR
git checkout $CHECKOUT_COMMIT

# Create necessary directories
mkdir -p obj-normal obj-symcc obj-aflgo-change

# Compile normal build with wllvm
cd ./obj-normal
export LLVM_COMPILER=clang
cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER="wllvm" -DCMAKE_C_FLAGS="-g -Wno-deprecated-declarations -O0 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div" -DCMAKE_CXX_COMPILER="wllvm++" -DCMAKE_CXX_FLAGS="-g -O0 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -Wno-error=main"
make -j32

wllvm -g -O0 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -o fuzzobj ../../fuzzobj.c -I ./ssl -I ./crypto ./ssl/libssl.a ./crypto/libcrypto.a -lssl -lcrypto -lpthread
# Generate bitcode and prepare files for SVF analysis
extract-bc fuzzobj
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

echo 'asn1_lib.c:459' > $TMP_DIR/target.txt

# Run SVF tool
$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./fuzzobj.bc

# Compile symcc build
cd ../obj-symcc

cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER="$SYMCC_DIR" -DCMAKE_C_FLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g -Wno-deprecated-declarations -O0 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div" -DCMAKE_CXX_COMPILER="$SYMXX_DIR" -DCMAKE_CXX_FLAGS="-g -O0 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -Wno-error=main" 
make -j32

cd ../obj-aflgo-change
CC=$AFLGO_DIR/instrument/aflgo-clang CXX=$AFLGO_DIR/instrument/aflgo-clang++ CFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" LDFLAGS="-ldl -lutil" ../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld
make clean
make 

# Create input directory and seed file
cd ..
mkdir -p in
echo "" > ./in/seed

# $AFLGO/afl-2.57b/afl-fuzz -m none -z exp -c 45m -i in -o out binutils/fuzzobj