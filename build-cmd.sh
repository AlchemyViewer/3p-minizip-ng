#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# bleat on references to undefined shell variables
set -u

MZ_SOURCE_DIR="minizip"

top="$(pwd)"
stage="$top"/stage

# load autobuild provided shell functions and variables
case "$AUTOBUILD_PLATFORM" in
    windows*)
        autobuild="$(cygpath -u "$AUTOBUILD")"
    ;;
    *)
        autobuild="$AUTOBUILD"
    ;;
esac
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

VERSION_HEADER_FILE="$MZ_SOURCE_DIR/mz.h"
version=$(sed -n -E 's/#define MZ_VERSION                      [(]"([0-9.]+)"[)]/\1/p' "${VERSION_HEADER_FILE}")
echo "${version}" > "${stage}/VERSION.txt"

pushd "$MZ_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        # ------------------------ windows, windows64 ------------------------
        windows*)
            load_vsvars

            if [ "$AUTOBUILD_ADDRSIZE" = 32 ]
            then
                archflags="/arch:SSE2"
            else
                archflags=""
            fi

            mkdir -p "$stage/include/minizip"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"

            mkdir -p "build_debug"
            pushd "build_debug"
                # Invoke cmake and use as official build

                cmake -G "$AUTOBUILD_WIN_CMAKE_GEN" -A "$AUTOBUILD_WIN_VSPLATFORM" -T host="$AUTOBUILD_WIN_VSHOST" .. -DBUILD_SHARED_LIBS:BOOL=OFF \
                    -DMZ_BUILD_TESTS=ON -DMZ_BUILD_UNIT_TESTS=ON -DMZ_SIGNING=OFF -DMZ_LIBCOMP=OFF -DMZ_ZIB_OVERRIDE=ON -DZLIB_COMPAT=ON -DMZ_FETCH_LIBS=OFF \
                    -DZLIB_INCLUDE_DIRS="$(cygpath -m $stage)/packages/include/zlib/" -DZLIB_LIBRARIES="$(cygpath -m $stage)/packages/lib/debug/zlibd.lib" -DZLIB_LIBRARY_DIRS="$(cygpath -m $stage)/packages/lib"

                cmake --build . --config Debug --clean-first

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Debug
                fi

                cp -a "Debug/libminizip.lib" "$stage/lib/debug/"
            popd

            mkdir -p "build_release"
            pushd "build_release"
                # Invoke cmake and use as official build
                cmake -G "$AUTOBUILD_WIN_CMAKE_GEN" -A "$AUTOBUILD_WIN_VSPLATFORM" -T host="$AUTOBUILD_WIN_VSHOST" .. -DBUILD_SHARED_LIBS:BOOL=OFF \
                    -DMZ_BUILD_TESTS=ON -DMZ_BUILD_UNIT_TESTS=ON -DMZ_SIGNING=OFF -DMZ_LIBCOMP=OFF -DMZ_ZIB_OVERRIDE=ON -DZLIB_COMPAT=ON -DMZ_FETCH_LIBS=OFF \
                    -DZLIB_INCLUDE_DIRS="$(cygpath -m $stage)/packages/include/zlib/" -DZLIB_LIBRARIES="$(cygpath -m $stage)/packages/lib/release/zlib.lib" -DZLIB_LIBRARY_DIRS="$(cygpath -m $stage)/packages/lib"

                cmake --build . --config Release --clean-first

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Release
                fi

                cp -a "Release/libminizip.lib" "$stage/lib/release/"
            popd
            cp -a mz.h "$stage/include/minizip"
            cp -a mz_os.h "$stage/include/minizip"
            cp -a mz_crypt.h "$stage/include/minizip"
            cp -a mz_strm.h "$stage/include/minizip"
            cp -a mz_strm_buf.h "$stage/include/minizip"
            cp -a mz_strm_mem.h "$stage/include/minizip"
            cp -a mz_strm_split.h "$stage/include/minizip"
            cp -a mz_strm_os.h "$stage/include/minizip"
            cp -a mz_zip.h "$stage/include/minizip"
            cp -a mz_zip_rw.h "$stage/include/minizip"
            cp -a mz_strm_zlib.h "$stage/include/minizip"
            cp -a mz_strm_pkcrypt.h "$stage/include/minizip"
            cp -a mz_strm_wzaes.h "$stage/include/minizip"
            cp -a mz_compat.h "$stage/include/minizip"
            cp -a zip.h "$stage/include/minizip"
            cp -a unzip.h "$stage/include/minizip"
        ;;

        # ------------------------- darwin, darwin64 -------------------------
        darwin*)
            # Setup osx sdk platform
            SDKNAME="macosx"
            export SDKROOT=$(xcodebuild -version -sdk ${SDKNAME} Path)
            export MACOSX_DEPLOYMENT_TARGET=10.13

            # Setup build flags
            ARCH_FLAGS="-arch x86_64"
            SDK_FLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -isysroot ${SDKROOT}"
            DEBUG_COMMON_FLAGS="$ARCH_FLAGS $SDK_FLAGS -Og -g -msse4.2 -fPIC -DPIC"
            RELEASE_COMMON_FLAGS="$ARCH_FLAGS $SDK_FLAGS -O3 -g -msse4.2 -fPIC -DPIC -fstack-protector-strong"
            DEBUG_CFLAGS="$DEBUG_COMMON_FLAGS"
            RELEASE_CFLAGS="$RELEASE_COMMON_FLAGS"
            DEBUG_CXXFLAGS="$DEBUG_COMMON_FLAGS -std=c++17"
            RELEASE_CXXFLAGS="$RELEASE_COMMON_FLAGS -std=c++17"
            DEBUG_CPPFLAGS="-DPIC"
            RELEASE_CPPFLAGS="-DPIC"
            DEBUG_LDFLAGS="$ARCH_FLAGS $SDK_FLAGS -Wl,-headerpad_max_install_names -Wl,-macos_version_min,$MACOSX_DEPLOYMENT_TARGET"
            RELEASE_LDFLAGS="$ARCH_FLAGS $SDK_FLAGS -Wl,-headerpad_max_install_names -Wl,-macos_version_min,$MACOSX_DEPLOYMENT_TARGET"

            mkdir -p "$stage/include/minizip"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"

            mkdir -p "build_debug"
            pushd "build_debug"
                CFLAGS="$DEBUG_CFLAGS" \
                CXXFLAGS="$DEBUG_CXXFLAGS" \
                CPPFLAGS="$DEBUG_CPPFLAGS" \
                LDFLAGS="$DEBUG_LDFLAGS" \
                cmake .. -GXcode -DBUILD_SHARED_LIBS:BOOL=OFF \
                    -DCMAKE_C_FLAGS="$DEBUG_CFLAGS" \
                    -DCMAKE_CXX_FLAGS="$DEBUG_CXXFLAGS" \
                    -DCMAKE_XCODE_ATTRIBUTE_GCC_OPTIMIZATION_LEVEL="0" \
                    -DCMAKE_XCODE_ATTRIBUTE_GCC_FAST_MATH=NO \
                    -DCMAKE_XCODE_ATTRIBUTE_GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
                    -DCMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT=dwarf \
                    -DCMAKE_XCODE_ATTRIBUTE_LLVM_LTO=NO \
                    -DCMAKE_XCODE_ATTRIBUTE_CLANG_X86_VECTOR_INSTRUCTIONS=sse4.2 \
                    -DCMAKE_XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD="c++17" \
                    -DCMAKE_XCODE_ATTRIBUTE_CLANG_CXX_LIBRARY="libc++" \
                    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="" \
                    -DCMAKE_OSX_ARCHITECTURES:STRING=x86_64 \
                    -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} \
                    -DCMAKE_OSX_SYSROOT=${SDKROOT} \
                    -DCMAKE_MACOSX_RPATH=YES -DCMAKE_INSTALL_PREFIX=$stage \
                    -DMZ_BUILD_TESTS=ON -DMZ_BUILD_UNIT_TESTS=ON -DMZ_SIGNING=OFF -DMZ_LIBCOMP=OFF -DMZ_ZIB_OVERRIDE=ON -DZLIB_COMPAT=ON -DMZ_FETCH_LIBS=OFF \
                    -DZLIB_INCLUDE_DIRS="${stage}/packages/include/zlib/" -DZLIB_LIBRARIES="${stage}/packages/lib/debug/libz.a" -DZLIB_LIBRARY_DIRS="${stage}/packages/lib"

                cmake --build . --config Debug

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Debug
                fi

                cp -a Debug/libminizip*.a* "${stage}/lib/debug/"
            popd

            mkdir -p "build_release"
            pushd "build_release"
                CFLAGS="$RELEASE_CFLAGS" \
                CXXFLAGS="$RELEASE_CXXFLAGS" \
                CPPFLAGS="$RELEASE_CPPFLAGS" \
                LDFLAGS="$RELEASE_LDFLAGS" \
                cmake .. -GXcode -DBUILD_SHARED_LIBS:BOOL=OFF \
                    -DCMAKE_C_FLAGS="$RELEASE_CFLAGS" \
                    -DCMAKE_CXX_FLAGS="$RELEASE_CXXFLAGS" \
                    -DCMAKE_XCODE_ATTRIBUTE_GCC_OPTIMIZATION_LEVEL="3" \
                    -DCMAKE_XCODE_ATTRIBUTE_GCC_FAST_MATH=NO \
                    -DCMAKE_XCODE_ATTRIBUTE_GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
                    -DCMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT=dwarf \
                    -DCMAKE_XCODE_ATTRIBUTE_LLVM_LTO=NO \
                    -DCMAKE_XCODE_ATTRIBUTE_CLANG_X86_VECTOR_INSTRUCTIONS=sse4.2 \
                    -DCMAKE_XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD="c++17" \
                    -DCMAKE_XCODE_ATTRIBUTE_CLANG_CXX_LIBRARY="libc++" \
                    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="" \
                    -DCMAKE_OSX_ARCHITECTURES:STRING=x86_64 \
                    -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} \
                    -DCMAKE_OSX_SYSROOT=${SDKROOT} \
                    -DCMAKE_MACOSX_RPATH=YES -DCMAKE_INSTALL_PREFIX=$stage \
                    -DMZ_BUILD_TESTS=ON -DMZ_BUILD_UNIT_TESTS=ON -DMZ_SIGNING=OFF -DMZ_LIBCOMP=OFF -DMZ_ZIB_OVERRIDE=ON -DZLIB_COMPAT=ON -DMZ_FETCH_LIBS=OFF \
                    -DZLIB_INCLUDE_DIRS="${stage}/packages/include/zlib/" -DZLIB_LIBRARIES="${stage}/packages/lib/release/libz.a" -DZLIB_LIBRARY_DIRS="${stage}/packages/lib"

                cmake --build . --config Release

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Release
                fi

                cp -a Release/libminizip*.a* "${stage}/lib/release/"
            popd

            cp -a mz.h "$stage/include/minizip"
            cp -a mz_os.h "$stage/include/minizip"
            cp -a mz_crypt.h "$stage/include/minizip"
            cp -a mz_strm.h "$stage/include/minizip"
            cp -a mz_strm_buf.h "$stage/include/minizip"
            cp -a mz_strm_mem.h "$stage/include/minizip"
            cp -a mz_strm_split.h "$stage/include/minizip"
            cp -a mz_strm_os.h "$stage/include/minizip"
            cp -a mz_zip.h "$stage/include/minizip"
            cp -a mz_zip_rw.h "$stage/include/minizip"
            cp -a mz_strm_zlib.h "$stage/include/minizip"
            cp -a mz_strm_pkcrypt.h "$stage/include/minizip"
            cp -a mz_strm_wzaes.h "$stage/include/minizip"
            cp -a mz_compat.h "$stage/include/minizip"
            cp -a zip.h "$stage/include/minizip"
            cp -a unzip.h "$stage/include/minizip"
        ;;            

        # -------------------------- linux, linux64 --------------------------
        linux*)
            unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Default target per autobuild build --address-size
            opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE}"
            DEBUG_COMMON_FLAGS="$opts -Og -g -fPIC -DPIC"
            RELEASE_COMMON_FLAGS="$opts -O3 -g -fPIC -DPIC -fstack-protector-strong -D_FORTIFY_SOURCE=2"
            DEBUG_CFLAGS="$DEBUG_COMMON_FLAGS"
            RELEASE_CFLAGS="$RELEASE_COMMON_FLAGS"
            DEBUG_CXXFLAGS="$DEBUG_COMMON_FLAGS -std=c++17"
            RELEASE_CXXFLAGS="$RELEASE_COMMON_FLAGS -std=c++17"
            DEBUG_CPPFLAGS="-DPIC"
            RELEASE_CPPFLAGS="-DPIC"

            # Handle any deliberate platform targeting
            if [ -z "${TARGET_CPPFLAGS:-}" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            # Fix up path for pkgconfig
            if [ -d "$stage/packages/lib/release/pkgconfig" ]; then
                fix_pkgconfig_prefix "$stage/packages"
            fi

            OLD_PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"

            mkdir -p "$stage/include/minizip"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"

            mkdir -p "build_debug"
            pushd "build_debug"
                # Debug first
                export PKG_CONFIG_PATH="$stage/packages/lib/debug/pkgconfig:${OLD_PKG_CONFIG_PATH}"
   
                CFLAGS="$DEBUG_CFLAGS" \
                CXXFLAGS="$DEBUG_CXXFLAGS" \
                CPPFLAGS="$DEBUG_CPPFLAGS" \
                cmake .. -G"Unix Makefiles" -DBUILD_SHARED_LIBS:BOOL=OFF \
                    -DCMAKE_C_FLAGS="$DEBUG_CFLAGS" \
                    -DCMAKE_CXX_FLAGS="$DEBUG_CXXFLAGS" \
                    -DCMAKE_INSTALL_PREFIX=$stage \
                    -DMZ_BUILD_TESTS=ON -DMZ_BUILD_UNIT_TESTS=ON -DMZ_SIGNING=OFF -DMZ_LIBCOMP=OFF -DMZ_ZIB_OVERRIDE=ON -DZLIB_COMPAT=ON -DMZ_FETCH_LIBS=OFF \
                    -DZLIB_INCLUDE_DIRS="${stage}/packages/include/zlib/" -DZLIB_LIBRARIES="${stage}/packages/lib/debug/libz.a" -DZLIB_LIBRARY_DIRS="${stage}/packages/lib"

                cmake --build . --config Debug

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Debug
                fi

                cp -a libminizip*.a* "${stage}/lib/debug/"
            popd

            mkdir -p "build_release"
            pushd "build_release"
                # Release last
                export PKG_CONFIG_PATH="$stage/packages/lib/release/pkgconfig:${OLD_PKG_CONFIG_PATH}"

                CFLAGS="$RELEASE_CFLAGS" \
                CXXFLAGS="$RELEASE_CXXFLAGS" \
                CPPFLAGS="$RELEASE_CPPFLAGS" \
                cmake .. -G"Unix Makefiles" -DBUILD_SHARED_LIBS:BOOL=OFF \
                    -DCMAKE_C_FLAGS="$RELEASE_CFLAGS" \
                    -DCMAKE_CXX_FLAGS="$RELEASE_CXXFLAGS" \
                    -DCMAKE_INSTALL_PREFIX=$stage \
                    -DMZ_BUILD_TESTS=ON -DMZ_BUILD_UNIT_TESTS=ON -DMZ_SIGNING=OFF -DMZ_LIBCOMP=OFF -DMZ_ZIB_OVERRIDE=ON -DZLIB_COMPAT=ON -DMZ_FETCH_LIBS=OFF \
                    -DZLIB_INCLUDE_DIRS="${stage}/packages/include/zlib/" -DZLIB_LIBRARIES="${stage}/packages/lib/release/libz.a" -DZLIB_LIBRARY_DIRS="${stage}/packages/lib"

                cmake --build . --config Release

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Release
                fi

                cp -a libminizip*.a* "${stage}/lib/release/"
            popd

            cp -a mz.h "$stage/include/minizip"
            cp -a mz_os.h "$stage/include/minizip"
            cp -a mz_crypt.h "$stage/include/minizip"
            cp -a mz_strm.h "$stage/include/minizip"
            cp -a mz_strm_buf.h "$stage/include/minizip"
            cp -a mz_strm_mem.h "$stage/include/minizip"
            cp -a mz_strm_split.h "$stage/include/minizip"
            cp -a mz_strm_os.h "$stage/include/minizip"
            cp -a mz_zip.h "$stage/include/minizip"
            cp -a mz_zip_rw.h "$stage/include/minizip"
            cp -a mz_strm_zlib.h "$stage/include/minizip"
            cp -a mz_strm_pkcrypt.h "$stage/include/minizip"
            cp -a mz_strm_wzaes.h "$stage/include/minizip"
            cp -a mz_compat.h "$stage/include/minizip"
            cp -a zip.h "$stage/include/minizip"
            cp -a unzip.h "$stage/include/minizip"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/minizip-ng.txt"
    # In case the section header changes, ensure that minizip-ng.txt is non-empty.
    # (With -e in effect, a raw test command has the force of an assert.)
    # Exiting here means we failed to match the copyright section header.
    # Check the README and adjust the awk regexp accordingly.
    [ -s "$stage/LICENSES/minizip-ng.txt" ]
popd
