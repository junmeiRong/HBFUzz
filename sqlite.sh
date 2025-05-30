wget https://www.sqlite.org/src/zip/8a8ffc86/SQLite-8a8ffc86.zip SQLite-3.8.9.zip
unzip SQLite-8a8ffc86.zip
cp -r SQLite-8a8ffc86
cd SQLite-sqlite3.c:97626
apt-get install tcl
apt-get install libreadline-dev

cp -r ../SQLite-8a8ffc86 ./

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

mkdir -p obj-normal obj-symcc obj-aflgo-change

cd ./obj-normal
export LLVM_COMPILER=clang
../SQLite-8a8ffc86/configure CC=wllvm --enable-debug CFLAGS="-O0 -g" --prefix=$PWD --enable-shared=false
make -j32 CC=wllvm CFLAGS="-g -O0"
make install 

cd bin
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc sqlite3
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

# echo 'sqlite3.c:97627' > $TMP_DIR/target.txt
# echo 'sqlite3.c:68209' > $TMP_DIR/target.txt
# echo 'sqlite3.c:26602' > $TMP_DIR/target.txt
# echo 'shell.c:929' > $TMP_DIR/target.txt
# echo 'sqlite3.c:72606' > $TMP_DIR/target.txt
# echo 'shell.c:4018' > $TMP_DIR/target.txt
# echo 'sqlite3.c:81998' > $TMP_DIR/target.txt
# echo 'sqlite3.c:94192' > $TMP_DIR/target.txt
# echo 'sqlite3.c:89936' > $TMP_DIR/target.txt
# echo 'shell.c:3601' > $TMP_DIR/target.txt
# echo 'sqlite3.c:87550' > $TMP_DIR/target.txt
# echo 'sqlite3.c:26602' > $TMP_DIR/target.txt
echo 'shell.c:2892' > $TMP_DIR/target.txt

$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./sqlite3.bc

cd ../../obj-symcc
../SQLite-8a8ffc86/configure CC=$SYMCC_DIR --enable-debug CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt  -O0 -g" --prefix=$PWD --enable-shared=false
make -j32 CC=$SYMCC_DIR CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g -O0"
make install 

cd ../obj-aflgo-change
../SQLite-8a8ffc86/configure CC=$AFLGO_DIR/instrument/aflgo-clang --enable-debug CFLAGS="-O0 -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" --prefix=$PWD --enable-shared=false
make -j32 CC=$AFLGO_DIR/instrument/aflgo-clang CFLAGS="-O0 -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt"
make install

# Create input directory and seed file
cd ../
mkdir -p in
cp ~/seeds/general_evaluation/sql/*  ./in

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz -m none -z exp -c 45m -i in -o out -t 1000+ -- ./obj-aflgo-change/bin/sqlite3
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz -n symcc -- ./obj-symcc/bin/sqlite3
export SYMCC_OUTPUT_DIR=`pwd`/tmp/results
export SYMCC_SVF_CDBB_FILE=`pwd`/tmp/cdbb2.txt
export SYMCC_SVF_DDBB_FILE=`pwd`/tmp/ddbb2.txt
export BR_FILE=`pwd`/tmp/brs.txt