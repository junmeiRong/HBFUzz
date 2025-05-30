#!/bin/bash

set -euo pipefail

# Variables
REPO_URL="https://git.libssh.org/projects/libssh.git"
REPO_DIR="libssh-2017-1272"
CHECKOUT_COMMIT="7c79b5c154ce2788cf5254a62468fee5112f7640"

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
cmake -DCMAKE_C_COMPILER="wllvm" \
          -DCMAKE_CXX_COMPILER="wllvm++" \
          -DCMAKE_C_FLAGS="-O0 -g -fcommon" \
          -DCMAKE_CXX_FLAGS="-O0 -g -fcommon" \
          -DWITH_STATIC_LIB=ON ..
make -j32

wllvm -g -O0 -c -w ~/aflgo/instrument/aflgo-runtime.o.c
wllvm++ -g -O0 -std=c++11 -c -w ~/aflgo/instrument/llvm_tools/compiler-rt/lib/fuzzer/afl/afl_driver.cpp -I~/aflgo/instrument/llvm_tools/compiler-rt/lib/fuzzer
ar r libFuzzingEngine-wllvm.a afl_driver.o aflgo-runtime.o.o
rm *.o

wllvm++ -g -O0 -std=c++11 ../../libssh_server_fuzzer.cc -I ../include/ ./src/libssh.a libFuzzingEngine-wllvm.a -lcrypto -lz -o fuzzobj

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

echo 'messages.c:1001' > $TMP_DIR/target.txt

# Run SVF tool
$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./fuzzobj.bc

# Compile symcc build
cd ../obj-symcc

export SYMCC_LIBCXX_PATH=/root/llvm-project-11/libcxx_symcc/

cmake -DCMAKE_C_COMPILER="$SYMCC_DIR" \
          -DCMAKE_CXX_COMPILER="$SYMXX_DIR" \
          -DCMAKE_C_FLAGS="-O0 -g -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -fcommon" \
          -DCMAKE_CXX_FLAGS="-O0 -g -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -fcommon" \
          -DWITH_STATIC_LIB=ON ..
make -j32

$SYMCC_DIR -g -O0 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -c -w ~/aflgo/instrument/aflgo-runtime.o.c
$SYMXX_DIR -g -O0 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -std=c++11 -c ~/aflgo/instrument/llvm_tools/compiler-rt/lib/fuzzer/afl/afl_driver.cpp -I~/aflgo/instrument/llvm_tools/compiler-rt/lib/fuzzer
ar r libFuzzingEngine-wllvm.a afl_driver.o aflgo-runtime.o.o
rm *.o

$SYMXX_DIR -g -O0 -std=c++11 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div ../../libssh_server_fuzzer.cc -I ../include/ ./src/libssh.a libFuzzingEngine-wllvm.a -lcrypto -lz -o fuzzobj

cd ../obj-aflgo-change

cmake -DCMAKE_C_COMPILER="$AFLGO_DIR/instrument/aflgo-clang" \
          -DCMAKE_CXX_COMPILER="$AFLGO_DIR/instrument/aflgo-clang++" \
          -DCMAKE_C_FLAGS="-O0 -g -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt -fcommon" \
          -DCMAKE_CXX_FLAGS="-O0 -g -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt -fcommon" \
          -DWITH_STATIC_LIB=ON ..
make -j32

clang -O0 -g -c -w ~/aflgo/instrument/aflgo-runtime.o.c
clang++ -g -O0 -std=c++11 -c ~/aflgo/instrument/llvm_tools/compiler-rt/lib/fuzzer/afl/afl_driver.cpp -I~/aflgo/instrument/llvm_tools/compiler-rt/lib/fuzzer
ar r libFuzzingEngine-wllvm.a afl_driver.o aflgo-runtime.o.o
rm *.o

clang++ -g -O0 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div -std=c++11 ../../libssh_server_fuzzer.cc -I ../include/ ./src/libssh.a libFuzzingEngine-wllvm.a -lcrypto -lz -o fuzzobj

# Create input directory and seed file
cd ..
mkdir -p in
echo "" > ./in/seed

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz-ssh -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/fuzzobj @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz-ssh -n symcc -- ./obj-symcc/fuzzobj @@


# cmake -G Ninja ../llvm -DLLVM_ENABLE_PROJECTS="libcxx;libcxxabi" -DLLVM_TARGETS_TO_BUILD="X86" -DLLVM_DISTRIBUTION_COMPONENTS="cxx;cxxabi;cxx-headers" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/some/convenient/location -DCMAKE_C_COMPILER=/path-to-symcc-with-simple-backend/symcc -DCMAKE_CXX_COMPILER=/path-to-symcc-with-simple-backend/sym++