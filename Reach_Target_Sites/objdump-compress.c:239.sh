#!/bin/bash

set -euo pipefail

# Variables
REPO_URL="https://gitee.com/mirrors_sourceware_org/git_binutils-gdb.git"
REPO_DIR="objdump"
CHECKOUT_COMMIT="7fa3933"

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

# Clone and checkout the specific commit
git clone $REPO_URL $REPO_DIR
cd $REPO_DIR
git checkout $CHECKOUT_COMMIT

# Create necessary directories
mkdir -p obj-normal obj-symcc obj-aflgo-change

# Compile normal build with wllvm
cd ./obj-normal
export LLVM_COMPILER=clang
CC=wllvm CXX=wllvm++ CFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -Wno-error -g" CXXFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -Wno-error -g" LDFLAGS="-ldl -lutil" ../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld
make -j32

# Generate bitcode and prepare files for SVF analysis
cd binutils
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc objdump
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

echo 'compress.c:239' > $TMP_DIR/target.txt

# Run SVF tool
$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./objdump.bc

# Compile symcc build
cd ../../obj-symcc
CC=$SYMCC_DIR CXX=$SYMXX_DIR CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error" CXXFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error " LDFLAGS="-ldl -lutil" ../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld
make -j32

cd ../obj-aflgo-change
CC=$AFLGO_DIR/instrument/aflgo-clang CXX=$AFLGO_DIR/instrument/aflgo-clang++ CFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" LDFLAGS="-ldl -lutil" ../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld
make -j32

# Create input directory and seed file
cd ..
mkdir -p in
cp /root/aflgo/afl-2.57b/testcases/others/elf/small_exec.elf ./in

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz9509 -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/binutils/objdump -S @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz9509 -n symcc -- ./obj-symcc/binutils/objdump -S @@