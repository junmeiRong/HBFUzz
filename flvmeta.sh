
git clone https://gitee.com/lsh-666/flvmeta.git flvmeta-dump_xml.c:134
cd flvmeta-dump_xml.c:134
git checkout v1.2.1

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

mkdir -p obj-normal obj-symcc obj-aflgo-change

cd ./obj-normal
export LLVM_COMPILER=clang
cmake .. -DCMAKE_C_COMPILER="wllvm" -DCMAKE_C_FLAGS="-O0 -g"
make -j32
# Generate bitcode and prepare files for SVF analysis
cd src/
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc flvmeta
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

# echo 'dump_xml.c:138' > $TMP_DIR/target.txt
# echo 'dump_xml.c:131' > $TMP_DIR/target.txt
# echo 'dump_xml.c:92' > $TMP_DIR/target.txt
# echo 'amf.c:546' > $TMP_DIR/target.txt
echo 'dump_xml.c:134' > $TMP_DIR/target.txt

$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./flvmeta.bc 

# Compile symcc build
cd ../../obj-symcc
cmake .. -DCMAKE_C_COMPILER="$SYMCC_DIR" -DCMAKE_C_FLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -O0 -g"
make -j32

cd ../obj-aflgo-change
cmake .. -DCMAKE_C_COMPILER="$AFLGO_DIR/instrument/aflgo-clang" -DCMAKE_C_FLAGS="-distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt -O0 -g"
make -j32

# Create input directory and seed file
cd ..
mkdir -p in
cp ~/seeds/general_evaluation/flv/1.flv in/

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz138 -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/src/flvmeta @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz138 -n symcc -- ./obj-symcc/src/flvmeta @@
