# HBFUzz
This repository contains code and data for the paper titled "Efficient Directed Hybrid Fuzzing via Target-Centric Seed Selection and Generation"

This tool consists of two components: fuzz testing with AFLGo and symbolic execution with SymCC.
It is divided into three stages:

* Static Analysis: Use the svf-tool to compute dependency relationships and basic block distance information (with .bc files obtained via wllvm).

* Compile the Executable for Symbolic Execution (instrumented with SymCC).

* Compile the Executable for Fuzz Testing (instrumented with AFLGo).

During execution, AFLGo and SymCC run concurrently.

The **symcc_fuzzing_helper** continuously monitors AFLGo’s output directory, identifies newly generated seeds, prioritizes them based on precomputed dependency and distance information, and performs symbolic execution accordingly.

Below is an example using the libming project:
# Operation Steps
## 0.Initialize the Project
```shell
git clone https://gitee.com/mxzell/libming.git libming-CVE-2018-7871  
cd libming-CVE-2018-7871  
git checkout b72cc2f  
mkdir -p obj-normal obj-symcc obj-aflgo-change  
./autogen.sh  
```

## 1.Static Analysis to Obtain Dependent Nodes
```shell
cd ./obj-normal
export LDFLAGS=-lpthread
export LLVM_COMPILER=clang
CC=wllvm CXX=wllvm++ CFLAGS="-fcommon -g" CXXFLAGS="-g" ../configure --disable-freetype --disable-shared --prefix=$PWD
make clean
make -j32

# Generate bitcode and prepare files for SVF analysis
cd util
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc swftophp
mkdir $TMP_DIR
mkdir $TMP_DIR/results
touch $TMP_DIR/cdbb.txt
touch $TMP_DIR/cdbb2.txt
touch $TMP_DIR/ddbb.txt
touch $TMP_DIR/ddbb2.txt

export SYMCC_OUTPUT_DIR=$TMP_DIR/results
export SYMCC_SVF_CDBB_FILE=$TMP_DIR/cdbb2.txt
export SYMCC_SVF_DDBB_FILE=$TMP_DIR/ddbb2.txt
export BR_FILE=$TMP_DIR/brs.txt

echo 'decompile.c:408' > $TMP_DIR/target.txt

# Run SVF tool
/root/svf-tool/src/svf-tool -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./swftophp.bc

```

### 2.Compile the SymCC Version
```shell
# Compile symcc build
cd ../../obj-symcc
CC=$SYMCC_DIR CXX=$SYMXX_DIR CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -fcommon -g" ../configure --disable-freetype --disable-shared --prefix=$PWD
make clean
make -j32
```

## 3.Compile the AFLGO Version
```shell
cd ../obj-aflgo-change
CC=$AFLGO_DIR/instrument/aflgo-clang CXX=$AFLGO_DIR/instrument/aflgo-clang++ CFLAGS="-fcommon -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" ../configure --disable-freetype --disable-shared --prefix=$PWD
make clean
make
```

## 4.Prepare Test Seeds
```shell
# Create input directory and seed file
cd ..
mkdir -p in
echo "" > ./in/seed
```

## 5.Start Dual-Engine Testing

### Terminal 1: Run AFLGO
```shell
~/aflgo/afl-2.57b/afl-fuzz -S fuzz-obj -m none -i in -o out ./util/swftophp @@
```

### Terminal 2: Run SymCC Assistant
```shell
~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz-obj -n symcc_obj ./util/swftophp @@
```

