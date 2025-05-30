git clone https://gitee.com/suyee0516/jhead.git normal
cd  normal

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

export LLVM_COMPILER=clang
make CC=wllvm CFLAGS="-g -O0"

# Generate bitcode and prepare files for SVF analysis
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc jhead
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

# echo 'jpgfile.c:46' > $TMP_DIR/target.txt
# echo 'jpgqguess.c:142' > $TMP_DIR/target.txt
echo 'exif.c:1548' > $TMP_DIR/target.txt

$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./jhead.bc

# Compile symcc build
cd ../
git clone https://gitee.com/suyee0516/jhead.git symcc
cd  symcc
make CC=$SYMCC_DIR CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g -O0"

cd ../
git clone https://gitee.com/suyee0516/jhead.git aflgo
cd  aflgo
make CC=$AFLGO_DIR/instrument/aflgo-clang CFLAGS="-distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt  -g -O0"


# Create input directory and seed file
cd ..
mkdir -p in
cp ~/aflgo/afl-2.57b/testcases/images/jpeg/not_kitty.jpg in/

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz1548 -m none -z exp -c 45m -i in -o out -- ./aflgo/jhead . @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz1548 -n symcc -- ./symcc/jhead . @@