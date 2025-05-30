wget https://dl.xpdfreader.com/old/xpdf-4.00.tar.gz
tar -xzf xpdf-4.00.tar.gz
cd xpdf-4.00 

mkdir afl++
cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER="/root/AFLplusplus/afl-clang-fast" -DCMAKE_C_FLAGS="-g -O0" -DCMAKE_CXX_COMPILER="/root/AFLplusplus/afl-clang-fast++" -DCMAKE_CXX_FLAGS="-g -O0"
make -j32

cd xpdf
mkdir in
cp ~/seeds/general_evaluation/pdf/* ./in/

~/AFLplusplus/afl-fuzz -m none -i in -o out -- ./pdftotext @@ /dev/null

export LLVM_COMPILER=clang
cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER="wllvm" -DCMAKE_C_FLAGS="-g -O0" -DCMAKE_CXX_COMPILER="wllvm++" -DCMAKE_CXX_FLAGS="-g -O0"
make -j32

cd xpdf
extract-bc pdftotext
opt -load-pass-plugin ~/llvm-tutor/build/libHelloWorld.so -passes="hello-world" ./pdftotext.bc -o test.bc
clang++ test.bc -o pdftotext_inst

wget https://dl.xpdfreader.com/old/xpdf-4.00.tar.gz
tar -xzf xpdf-4.00.tar.gz

cp -r xpdf-4.00 ./xpdf-XRef.cc:193
cd ./xpdf-XRef.cc:193

export SYMCC_DIR="/root/symcc/build-qsym/symcc"
export SYMXX_DIR="/root/symcc/build-qsym/sym++"
export SVF_TOOL="/root/svf-tool/src/svf-tool"
export AFLGO_DIR="/root/aflgo"

mkdir -p obj-normal obj-symcc obj-aflgo-change

cd ./obj-normal
export LLVM_COMPILER=clang
cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER="wllvm" -DCMAKE_C_FLAGS="-g -O0" -DCMAKE_CXX_COMPILER="wllvm++" -DCMAKE_CXX_FLAGS="-g -O0"
make -j32

cd xpdf
export TMP_DIR="$PWD/tmp"
export DIST_DIR=$TMP_DIR

extract-bc pdftotext
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
export SYMCC_REGULAR_LIBCXX=yes

echo 'XRef.cc:192' > $TMP_DIR/target.txt

$SVF_TOOL -target=$TMP_DIR/target.txt -cdbb-output=$TMP_DIR/cdbb.txt -ddbb-output=$TMP_DIR/ddbb.txt -dist-output=$TMP_DIR/dist.txt -deep-output=$TMP_DIR/deep.txt -cbrset-output=$TMP_DIR/cbrset.txt -brs-output=$TMP_DIR/brs.txt ./pdftotext.bc

cd ../../obj-symcc
cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER="$SYMCC_DIR" -DCMAKE_C_FLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g -O0" -DCMAKE_CXX_COMPILER="$SYMXX_DIR" -DCMAKE_CXX_FLAGS="-mllvm -cdbb-in-file=$TMP_DIR/cdbb.txt -mllvm -cdbb-out-file=$TMP_DIR/cdbb2.txt -mllvm -ddbb-in-file=$TMP_DIR/ddbb.txt -mllvm -ddbb-out-file=$TMP_DIR/ddbb2.txt -g -O0"
make -j32 

cd ../obj-aflgo-change
../SQLite-8a8ffc86/configure CC=$AFLGO_DIR/instrument/aflgo-clang --enable-debug CFLAGS="-O0 -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" --prefix=$PWD --enable-shared=false
make -j32 CC=$AFLGO_DIR/instrument/aflgo-clang CFLAGS="-O0 -g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt" CXXFLAGS="-g -distance=$DIST_DIR/dist.txt -deep=$DIST_DIR/deep.txt -ctlbrs=$DIST_DIR/brs.txt"
make install

# Create input directory and seed file
cd ../
mkdir -p in
cp ~/seeds/general_evaluation/sql/*  ./in

# ~/aflgo/afl-2.57b/afl-fuzz -S fuzz2892 -m none -z exp -c 45m -i in -o out -t 1000+ -- ./obj-aflgo-change/bin/pdftotext
# ~/.cargo/bin/symcc_fuzzing_helper -o out -a fuzz2892 -n symcc -- ./obj-symcc/bin/pdftotext
