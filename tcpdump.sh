git clone https://gitee.com/aggshsjs/tcpdump.git tcp-print-snmp.c:607
cd tcp-print-snmp.c:607
git checkout tcpdump-4.8.1

git clone https://gitee.com/wuyexkx/libpcap.git
git clone https://gitee.com/aggshsjs/tcpdump.git

cd libpcap
git checkout libpcap-1.8.1
cd ../tcpdump
git checkout tcpdump-4.8.1
export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

cd ..
# Create necessary directories
mkdir -p obj-normal obj-symcc obj-aflgo-change

# Compile normal build with wllvm
cd ./obj-normal
cp -r ../{libpcap,tcpdump} .
cd libpcap/
export LLVM_COMPILER=clang
CC=wllvm CFLAGS="-g" ./configure
make -j32

cd ../tcpdump
CC=wllvm CFLAGS="-g" ./configure
make -j32
# Generate bitcode and prepare files for SVF analysis
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc tcpdump
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

# echo 'print-aodv.c:265' > $TMP_DIR/target.txt
# echo 'print-rsvp.c:1253' > $TMP_DIR/target.txt
echo 'print-snmp.c:607' > $TMP_DIR/target.txt

$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./tcpdump.bc

# Compile symcc build
# CCOPT = -g 
cd ../../obj-symcc
cp -r ../{libpcap,tcpdump} .
cd libpcap/
CC=$SYMCC_DIR CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g"  ./configure
make  -j32
cd ../tcpdump
CC=$SYMCC_DIR CFLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g"  ./configure
make  -j32

cd ../../obj-aflgo-change
cp -r ../{libpcap,tcpdump} .
cd libpcap/
CC=$AFLGO_DIR/instrument/aflgo-clang CFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" ./configure
make -j32 
cd ../tcpdump
CC=$AFLGO_DIR/instrument/aflgo-clang CFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" ./configure
make -j32 

# Create input directory and seed file
cd ../..
mkdir -p in
cp ~/seeds/general_evaluation/tcpdump100/1 ./in

# ~/aflgo/examples/tcp-print-snmp.c:607# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz607 -m none -z exp -c 45m -i in -o out -- ./obj-aflgo-change/tcpdump/tcpdump -e -vv -nr @@
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz607 -n symcc -- ./obj-symcc/tcpdump/tcpdump -e -vv -nr @@
