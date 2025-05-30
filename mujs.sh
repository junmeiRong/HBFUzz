git clone https://gitee.com/sskey/mujs.git 
cd mujs
git checkout 1.0.2
cd ..

cp  -r ./mujs obj-normal
cp  -r ./mujs obj-symcc
cp  -r ./mujs obj-aflgo-change

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

cd ./obj-normal
export LLVM_COMPILER=clang
make CC=wllvm CFLAGS="-g -O0"

cd ./build/release/

export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc mujs
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

# echo 'jsrun.c:573' > $TMP_DIR/target.txt
# echo 'jsvalue.c:364' > $TMP_DIR/target.txt
# echo 'jsrun.c:692' > $TMP_DIR/target.txt
# echo 'jsgc.c:98' > $TMP_DIR/target.txt
# echo 'jscompile.c:418' > $TMP_DIR/target.txt
# echo 'jsgc.c:114' > $TMP_DIR/target.txt
# echo 'jsdump.c:233' > $TMP_DIR/target.txt
# echo 'jsrun.c:1635' > $TMP_DIR/target.txt
echo 'jsparse.c:929' > $TMP_DIR/target.txt

$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./mujs.bc

cd ../../../obj-symcc
make  CC=$SYMCC_DIR CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g"

cd ../obj-aflgo-change
make  CC=$AFLGO_DIR/instrument/aflgo-clang CFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt"

cd ..
mkdir -p in
cp ~/seeds/general_evaluation/mujs/* in/

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz -m none -z exp -c 45m -i in -o out -t 2000+ -- ./obj-aflgo-change/build/release/mujs @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz -n symcc -- ./obj-symcc/build/release/mujs @@
