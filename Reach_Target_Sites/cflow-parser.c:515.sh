# Clone and checkout the specific commit
wget https://ftp.gnu.org/gnu/cflow/cflow-1.6.tar.gz
tar zxvf cflow-1.6.tar.gz
mv cflow-1.6 cflow-parser.c:252
cd cflow-parser.c:252

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

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

echo 'parser.c:515' > $TMP_DIR/target.txt

# Run SVF tool
$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./cflow.bc

# Compile symcc build
cd ../../obj-symcc
CC=/data/symcc_HBFuzz/symcc/build_symcc/symcc CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -O0 -g"  ../configure
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

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz1783 -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/src/cflow @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz1783 -n symcc -- ./obj-symcc/src/cflow @@
# ~/gdb/gdb_cflow.sh ./out/fuzz281/crashes/ ./obj-normal/src/cflow