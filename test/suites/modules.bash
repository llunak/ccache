SUITE_modules_PROBE() {
    if ! $COMPILER_TYPE_CLANG; then
        echo "-fmodules/-fcxx-modules not supported by compiler"
        return
    fi
 }

SUITE_modules_SETUP() {
    unset CCACHE_NODIRECT
    export CCACHE_DEPEND=1

    cat <<EOF >test1.h
#include <string>
EOF
    backdate test1.h

cat <<EOF >module.modulemap
module "Test1" {
  header "test1.h"
  export *
}
EOF
    backdate module.modulemap

   cat <<EOF >test1.cpp
#import "test1.h"
int main() { return 0; }
EOF
}

expect_file_contains() {
    local file="$1"
    local string="$2"

    if [ ! -f "$file" ]; then
        test_failed "$file not found"
    fi
    if ! grep -q "$string" "$file"; then
        test_failed "File $file does not contain: $string. Actual content: $(cat $file)"
    fi
}

SUITE_modules() {
    # -------------------------------------------------------------------------
    TEST "preprocessor output"
    $COMPILER -fmodules -fcxx-modules test1.cpp -E > test1.preprocessed.cpp
    expect_file_contains "test1.preprocessed.cpp" "#pragma clang module import Test1"

    # -------------------------------------------------------------------------
    TEST "fall back to real compiler, no depend mode"

    unset CCACHE_DEPEND

    $CCACHE_COMPILE -fmodules -fcxx-modules -c test1.cpp -MD
    expect_stat 'unsupported compiler option' 1

    $CCACHE_COMPILE -fmodules -fcxx-modules -c test1.cpp -MD
    expect_stat 'unsupported compiler option' 2

    # -------------------------------------------------------------------------
    TEST "cache hit"

    $CCACHE_COMPILE -fmodules -fcxx-modules -c test1.cpp -MD
    expect_stat 'cache hit (direct)' 0
    expect_stat 'cache miss' 1

    $CCACHE_COMPILE -fmodules -fcxx-modules -c test1.cpp -MD
    expect_stat 'cache hit (direct)' 1
    expect_stat 'cache miss' 1

    # -------------------------------------------------------------------------
    TEST "cache miss"

    $CCACHE_COMPILE -MD -fmodules -fcxx-modules -c test1.cpp -MD
    expect_stat 'cache miss' 1

    cat <<EOF >test1.h
#include <string>
void f();
EOF

    $CCACHE_COMPILE -MD -fmodules -fcxx-modules -c test1.cpp -MD
    expect_stat 'cache miss' 2
}
