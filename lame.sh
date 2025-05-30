#!/bin/bash

wget https://sourceforge.net/projects/lame/files/lame/3.99/lame-3.99.5.tar.gz/download
tar -xzf download 
mv lame-3.99.5/ lame-get_audio.c:1379

cd lame-get_audio.c:1379

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

# Compile normal build with wllvm
mkdir -p obj-normal obj-symcc obj-aflgo-change

cd ./obj-normal
export LLVM_COMPILER=clang
CC=wllvm CXX=wllvm++ CXXFLAGS="-g -O0" CFLAGS="-g -O0" ../configure --disable-shared  --prefix=$PWD
make -j32
make install

# Generate bitcode and prepare files for SVF analysis
cd bin/
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc lame
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

# echo 'get_audio.c:1397' > $TMP_DIR/target.txt
echo 'get_audio.c:469' > $TMP_DIR/target.txt

# Run SVF tool
$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./lame.bc

# Compile symcc build
cd ../../obj-symcc/
CC=$SYMCC_DIR CXX=$SYMXX_DIR CXXFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -O0" CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -O0" ../configure --disable-shared  --prefix=$PWD
make -j32

cd ../obj-aflgo-change
CC=$AFLGO_DIR/instrument/aflgo-clang CXX=$AFLGO_DIR/instrument/aflgo-clang++ CFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" LDFLAGS="-ldl -lutil" ../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld
make clean
make -j32 

# Create input directory and seed file
cd ..
mkdir -p in
echo "" > ./in/seed

# $AFLGO/afl-2.57b/afl-fuzz -m none -z exp -c 45m -i in -o out binutils/cxxfilt