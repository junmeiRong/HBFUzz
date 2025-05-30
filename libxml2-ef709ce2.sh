#!/bin/bash

set -euo pipefail

# Variables
REPO_URL="https://gitlab.gnome.org/GNOME/libxml2.git"
REPO_DIR="libxml2_ef709ce2"
CHECKOUT_COMMIT="ef709ce2"

SYMCC_DIR="/root/symcc/build-qsym/symcc"
SYMXX_DIR="/root/symcc/build-qsym/sym++"
SVF_TOOL="/root/svf-tool/src/svf-tool"
AFLGO_DIR="/root/aflgo"

# Clone and checkout the specific commit
git clone $REPO_URL $REPO_DIR
cd $REPO_DIR
git checkout $CHECKOUT_COMMIT

./autogen.sh; make distclean

# Create necessary directories
mkdir -p obj-normal obj-symcc obj-aflgo-change

# Compile normal build with wllvm
cd ./obj-normal
export LLVM_COMPILER=clang
CC=wllvm CXX=wllvm++ CFLAGS="-g" CXXFLAGS="-g" LDFLAGS="-lpthread" ../configure  --disable-shared --prefix=`pwd`
make clean
make -j32

# Generate bitcode and prepare files for SVF analysis
TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc xmllint
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

echo 'valid.c:1279' > $TMP_DIR/target.txt

# Run SVF tool
$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./xmllint.bc

# Compile symcc build
cd ../obj-symcc
CC=$SYMCC_DIR CXX=$SYMXX_DIR CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g" CXXFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g " LDFLAGS="-ldl -lutil" ../configure  --disable-shared --prefix=`pwd`
make clean
make -j32

cd ../obj-aflgo-change
CC=$AFLGO_DIR/instrument/aflgo-clang CXX=$AFLGO_DIR/instrument/aflgo-clang++ CFLAGS="-fsanitize=address -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-fsanitize=address -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" LDFLAGS="-ldl -lutil -fsanitize=address" ../configure  --disable-shared --without-debug --without-ftp --without-http --without-legacy --without-python --prefix=`pwd`
make clean
AFL_USE_ASAN=1 make -j32

# Create input directory and seed file
cd ..
mkdir -p in
cp $AFLGO_DIR/afl-2.57b/testcases/others/xml/small_document.xml ./in

# $AFLGO/afl-2.57b/afl-fuzz -m none -z exp -c 45m -i in -o out ./xmllint --valid --recover @@