#!/bin/bash

set -euo pipefail

# Variables
REPO_URL="https://ftp.gnu.org/gnu/cflow/cflow-1.6.tar.gz"
REPO_DIR="cflow-parser.c:109"

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

# Clone and checkout the specific commit
wget $REPO_URL
tar zxvf cflow-1.6.tar.gz
rm cflow-1.6.tar.gz
mv cflow-1.6 $REPO_DIR
cd $REPO_DIR

# Create necessary directories
mkdir -p obj-normal obj-symcc obj-aflgo-change

# Compile normal build with wllvm
cd ./obj-normal
export LLVM_COMPILER=clang
CC=wllvm CFLAGS="-O0 -g" ../configure
make -j32

# Generate bitcode and prepare files for SVF analysis
cd src
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc cflow
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

# echo 'parser.c:109' > $TMP_DIR/target.txt
# echo 'c.c:1783' > $TMP_DIR/target.txt
# echo 'parser.c:834' > $TMP_DIR/target.txt
# echo 'parser.c:252' > $TMP_DIR/target.txt
# echo 'c.c:1780' > $TMP_DIR/target.txt
# echo 'symbol.c:226' > $TMP_DIR/target.txt
# echo 'gnu.c:35' > $TMP_DIR/target.txt
# echo 'symbol.c:145' > $TMP_DIR/target.txt
# echo 'parser.c:1128' > $TMP_DIR/target.txt
# echo 'parser.c:747' > $TMP_DIR/target.txt
echo 'parser.c:516' > $TMP_DIR/target.txt
# Run SVF tool
$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./cflow.bc

# Compile symcc build
cd ../../obj-symcc
CC=$SYMCC_DIR CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -O0 -g"  ../configure
make clean
make -j32

cd ../obj-aflgo-change
CC=$AFLGO_DIR/instrument/aflgo-clang CFLAGS="-O0 -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" ../configure
make clean
make -j32

# Create input directory and seed file
cd ..
mkdir -p in
cp ~/seeds/general_evaluation/cflow/1.c ./in/

/root/aflgo/afl-2.57b/afl-fuzz -S fuzz515 -t 2000 -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/src/cflow @@

~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz515 -n symcc -- ./obj-symcc/src/cflow @@

# echo "#include <stdio.h>

# // 一个简单的加法函数
# int add(int a, int b) {
#     return a + b;
# }

# // 计算两个数的差值
# int subtract(int a, int b) {
#     return a - b;
# }

# // 主函数
# int main() {
#     int x = 5;
#     int y = 3;
#     int result;

#     // 根据条件选择加法或减法
#     if (x > y) {
#         result = add(x, y);
#         printf("x + y = %d\n", result);
#     } else {
#         result = subtract(x, y);
#         printf("x - y = %d\n", result);
#     }

#     return 0;
# }" > ./in/seed

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz109 -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/src/cflow @@ --tree --format=posix --all /dev/null
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz109 -n symcc -- ./obj-symcc/src/cflow @@ --tree --format=posix --all /dev/null
# ~/gdb/gdb_cflow.sh ./out/fuzz109/crashes/ ./obj-normal/src/cflow