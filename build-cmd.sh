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

            mkdir -p "$stage/include/minizip"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"

            mkdir -p "build_debug"
            pushd "build_debug"
                # Invoke cmake and use as official build

                cmake -G Ninja .. -DCMAKE_BUILD_TYPE=Debug -DBUILD_SHARED_LIBS:BOOL=OFF -DMZ_BUILD_TESTS=ON -DMZ_BUILD_UNIT_TESTS=ON \
                    -DMZ_ZLIB=ON -DMZ_ZLIB_OVERRIDE=ON -DMZ_FETCH_LIBS=OFF \
                    -DZLIB_INCLUDE_DIRS="$(cygpath -m $stage)/packages/include/zlib/" -DZLIB_LIBRARIES="$(cygpath -m $stage)/packages/lib/debug/zlibd.lib" -DZLIB_LIBRARY_DIRS="$(cygpath -m $stage)/packages/lib" \
                    -DMZ_ZSTD=ON -DMZ_ZSTD_OVERRIDE=ON \
                    -DZSTD_INCLUDE_DIRS="$(cygpath -m $stage)/packages/include/" -DZSTD_LIBRARIES="$(cygpath -m $stage)/packages/lib/debug/zstd_static.lib" -DZSTD_LIBRARY_DIRS="$(cygpath -m $stage)/packages/lib"

                cmake --build . --config Debug --clean-first

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Debug
                fi

                cp -a "minizip.lib" "$stage/lib/debug/"
            popd

            mkdir -p "build_release"
            pushd "build_release"
                # Invoke cmake and use as official build
                cmake -G Ninja .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS:BOOL=OFF -DMZ_BUILD_TESTS=ON -DMZ_BUILD_UNIT_TESTS=ON \
                    -DMZ_ZLIB=ON -DMZ_ZLIB_OVERRIDE=ON -DMZ_FETCH_LIBS=OFF \
                    -DZLIB_INCLUDE_DIRS="$(cygpath -m $stage)/packages/include/zlib/" -DZLIB_LIBRARIES="$(cygpath -m $stage)/packages/lib/release/zlib.lib" -DZLIB_LIBRARY_DIRS="$(cygpath -m $stage)/packages/lib" \
                    -DMZ_ZSTD=ON -DMZ_ZSTD_OVERRIDE=ON \
                    -DZSTD_INCLUDE_DIRS="$(cygpath -m $stage)/packages/include/" -DZSTD_LIBRARIES="$(cygpath -m $stage)/packages/lib/release/zstd_static.lib" -DZSTD_LIBRARY_DIRS="$(cygpath -m $stage)/packages/lib"

                cmake --build . --config Release --clean-first

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Release
                fi

                cp -a "minizip.lib" "$stage/lib/release/"
                cp -a zip.h "$stage/include/minizip"
                cp -a unzip.h "$stage/include/minizip"
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
        ;;

        # ------------------------- darwin, darwin64 -------------------------
        darwin*)
            # Setup build flags
            C_OPTS_X86="-arch x86_64 $LL_BUILD_RELEASE_CFLAGS"
            C_OPTS_ARM64="-arch arm64 $LL_BUILD_RELEASE_CFLAGS"
            CXX_OPTS_X86="-arch x86_64 $LL_BUILD_RELEASE_CXXFLAGS"
            CXX_OPTS_ARM64="-arch arm64 $LL_BUILD_RELEASE_CXXFLAGS"
            LINK_OPTS_X86="-arch x86_64 $LL_BUILD_RELEASE_LINKER"
            LINK_OPTS_ARM64="-arch arm64 $LL_BUILD_RELEASE_LINKER"

            # deploy target
            export MACOSX_DEPLOYMENT_TARGET=${LL_BUILD_DARWIN_BASE_DEPLOY_TARGET}

            mkdir -p "build_release_x86"
            pushd "build_release_x86"
                CFLAGS="$C_OPTS_X86" \
                CXXFLAGS="$CXX_OPTS_X86" \
                LDFLAGS="$LINK_OPTS_X86" \
                cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS:BOOL=OFF \
                    -DCMAKE_C_FLAGS="$C_OPTS_X86" \
                    -DCMAKE_CXX_FLAGS="$CXX_OPTS_X86" \
                    -DCMAKE_OSX_ARCHITECTURES:STRING=x86_64 \
                    -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} \
                    -DCMAKE_MACOSX_RPATH=YES \
                    -DCMAKE_INSTALL_PREFIX="$stage/release_x86" \
                    -DMZ_LIBCOMP=OFF -DMZ_ZLIB=ON -DMZ_ZLIB_OVERRIDE=ON -DMZ_FETCH_LIBS=OFF -DMZ_BUILD_TESTS=ON -DMZ_BUILD_UNIT_TESTS=ON \
                    -DZLIB_INCLUDE_DIRS="${stage}/packages/include/zlib/" -DZLIB_LIBRARIES="${stage}/packages/lib/release/libz.a" -DZLIB_LIBRARY_DIRS="${stage}/packages/lib" \
                    -DMZ_ZSTD=ON -DMZ_ZSTD_OVERRIDE=ON \
                    -DZSTD_INCLUDE_DIRS="${stage}/packages/include/" -DZSTD_LIBRARIES="${stage}/packages/lib/release/libzstd.a" -DZSTD_LIBRARY_DIRS="${stage}/packages/lib" \

                cmake --build . --config Release
                cmake --install . --config Release

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Release
                fi
            popd

            mkdir -p "build_release_arm64"
            pushd "build_release_arm64"
                CFLAGS="$C_OPTS_ARM64" \
                CXXFLAGS="$CXX_OPTS_ARM64" \
                LDFLAGS="$LINK_OPTS_ARM64" \
                cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS:BOOL=OFF \
                    -DCMAKE_C_FLAGS="$C_OPTS_ARM64" \
                    -DCMAKE_CXX_FLAGS="$CXX_OPTS_ARM64" \
                    -DCMAKE_OSX_ARCHITECTURES:STRING=arm64 \
                    -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} \
                    -DCMAKE_MACOSX_RPATH=YES \
                    -DCMAKE_INSTALL_PREFIX="$stage/release_arm64" \
                    -DMZ_LIBCOMP=OFF -DMZ_ZLIB=ON -DMZ_ZLIB_OVERRIDE=ON -DMZ_FETCH_LIBS=OFF -DMZ_BUILD_TESTS=ON -DMZ_BUILD_UNIT_TESTS=ON \
                    -DZLIB_INCLUDE_DIRS="${stage}/packages/include/zlib/" -DZLIB_LIBRARIES="${stage}/packages/lib/release/libz.a" -DZLIB_LIBRARY_DIRS="${stage}/packages/lib" \
                    -DMZ_ZSTD=ON -DMZ_ZSTD_OVERRIDE=ON \
                    -DZSTD_INCLUDE_DIRS="${stage}/packages/include/" -DZSTD_LIBRARIES="${stage}/packages/lib/release/libzstd.a" -DZSTD_LIBRARY_DIRS="${stage}/packages/lib" \

                cmake --build . --config Release
                cmake --install . --config Release

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Release
                fi
            popd

            # prepare staging dirs
            mkdir -p "$stage/include/minizip"
            mkdir -p "$stage/lib/release"

            # create fat libraries
            lipo -create ${stage}/release_x86/lib/libminizip.a ${stage}/release_arm64/lib/libminizip.a -output ${stage}/lib/release/libminizip.a

            # copy headers
            mv $stage/release_x86/include/minizip/* $stage/include/minizip
        ;;

        # -------------------------- linux, linux64 --------------------------
        linux*)
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            unset DISTCC_HOSTS CFLAGS CPPFLAGS CXXFLAGS

            # Default target per --address-size
            opts_c="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE_CFLAGS}"
            opts_cxx="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE_CXXFLAGS}"

            # Handle any deliberate platform targeting
            if [ -z "${TARGET_CPPFLAGS:-}" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            mkdir -p "$stage/include/minizip"

            mkdir -p "build_release"
            pushd "build_release"
                # Release last
                CFLAGS="$opts_c" \
                CXXFLAGS="$opts_cxx" \
                cmake .. -G Ninja -DBUILD_SHARED_LIBS:BOOL=OFF \
                    -DCMAKE_BUILD_TYPE=Release \
                    -DCMAKE_C_FLAGS="$opts_c" \
                    -DCMAKE_CXX_FLAGS="$opts_cxx" \
                    -DCMAKE_INSTALL_PREFIX=$stage \
                    -DMZ_ZLIB=ON -DMZ_ZLIB_OVERRIDE=ON -DZLIB_COMPAT=ON -DMZ_FETCH_LIBS=OFF -DMZ_BUILD_TESTS=ON -DMZ_BUILD_UNIT_TESTS=ON \
                    -DZLIB_INCLUDE_DIRS="${stage}/packages/include/" -DZLIB_LIBRARIES="${stage}/packages/lib/libz.a" -DZLIB_LIBRARY_DIRS="${stage}/packages/lib" \
                    -DMZ_ZSTD=ON -DMZ_ZSTD_OVERRIDE=ON \
                    -DZSTD_INCLUDE_DIRS="${stage}/packages/include/" -DZSTD_LIBRARIES="${stage}/packages/lib/libzstd.a" -DZSTD_LIBRARY_DIRS="${stage}/packages/lib" \

                cmake --build . --config Release

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Release
                fi

                cmake --install . --config Release
            popd
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
