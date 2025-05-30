#!/bin/bash

set -euo pipefail

# Variables
REPO_URL="https://github.com/libjpeg-turbo/libjpeg-turbo.git"
REPO_DIR="libjpeg-turbo-07-2017"
CHECKOUT_COMMIT="b0971e47d76fdb81270e93bbf11ff5558073350d"

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
autoreconf -fiv

# Compile normal build with wllvm
cd ./obj-normal
export LLVM_COMPILER=clang
CC=wllvm CFLAGS="-O0 -g" ../configure --disable-shared
make -j32

wllvm -g -O0 -fsanitize=address ../../libarchive_fuzzer.cc -I ../libarchive .libs/libarchive.a libFuzzingEngine-wllvm.a -lz -lbz2 -lxml2 -lcrypto -lssl -llzma -llzo2 -o fuzzobj

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

echo 'archive_read_support_format_warc.c:537' > $TMP_DIR/target.txt

# Run SVF tool
$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./fuzzobj.bc

# Compile symcc build
cd ../obj-symcc

CC=$SYMCC_DIR CXX=$SYMXX_DIR CFLAGS="-O0 -g -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt" CXXFLAGS="-O0 -g -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt" LDFLAGS="-lz" ../configure --disable-shared --without-nettle
make -j32

$SYMCC_DIR -g -O0 -mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -c -w ~/aflgo/instrument/aflgo-runtime.o.c
$SYMXX_DIR -g -O0 -mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -std=c++11 -c ~/aflgo/instrument/llvm_tools/compiler-rt/lib/fuzzer/afl/afl_driver.cpp -I~/aflgo/instrument/llvm_tools/compiler-rt/lib/fuzzer
ar r libFuzzingEngine-wllvm.a afl_driver.o aflgo-runtime.o.o
rm *.o

export SYMCC_REGULAR_LIBCXX=yes
$SYMXX_DIR -g -O0 -std=c++11 -fsanitize=address ../../libarchive_fuzzer.cc -I ../libarchive .libs/libarchive.a libFuzzingEngine-wllvm.a -lz -lbz2 -lxml2 -lcrypto -lssl -llzma -llzo2 -o fuzzobj

cd ../obj-aflgo-change

CC=$AFLGO_DIR/instrument/aflgo-clang CXX=$AFLGO_DIR/instrument/aflgo-clang++ CFLAGS="-O0 -g -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-O0 -g -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" LDFLAGS="-lz -llzo2" ../configure --disable-shared --without-nettle
make -j32

clang -O0 -g -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -c -w ~/aflgo/instrument/aflgo-runtime.o.c
clang++ -g -O0 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -std=c++11 -c ~/aflgo/instrument/llvm_tools/compiler-rt/lib/fuzzer/afl/afl_driver.cpp -I~/aflgo/instrument/llvm_tools/compiler-rt/lib/fuzzer
ar r libFuzzingEngine-wllvm.a afl_driver.o aflgo-runtime.o.o
rm *.o

clang++ -g -O0 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -std=c++11 ../../libarchive_fuzzer.cc -I ../libarchive .libs/libarchive.a libFuzzingEngine-wllvm.a -lz -lbz2 -lxml2 -lcrypto -lssl -llzma -llzo2 -o fuzzobj

# Create input directory and seed file
cd ..
mkdir -p in
echo "" > ./in/seed

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz-arc -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/fuzzobj @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz-arc -n symcc -- ./obj-symcc/fuzzobj @@