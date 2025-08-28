#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# bleat on references to undefined shell variables
set -u

MINIZLIB_SOURCE_DIR="minizip-ng"

top="$(pwd)"
stage="$top"/stage

[ -f "$stage"/packages/include/zlib-ng/zlib.h ] || \
{ echo "You haven't yet run 'autobuild install'." 1>&2; exit 1; }

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

# remove_cxxstd apply_patch
source "$(dirname "$AUTOBUILD_VARIABLES_FILE")/functions"

apply_patch "$top/patches/update-cmake-version-compat.patch" "$MINIZLIB_SOURCE_DIR"

# CMake configuration options for all platforms
config=( \
    -DBUILD_SHARED_LIBS=OFF \
    -DMZ_BUILD_TESTS=OFF \
    -DMZ_BUILD_UNIT_TESTS=OFF \
    -DMZ_BZIP2=OFF \
    -DMZ_COMPAT=ON \
    -DMZ_FETCH_LIBS=OFF \
    -DMZ_FORCE_FETCH_LIBS=OFF \
    -DMZ_ICONV=OFF \
    -DMZ_LIBBSD=OFF \
    -DMZ_LIBCOMP=OFF \
    -DMZ_LZMA=OFF \
    -DMZ_OPENSSL=OFF \
    -DMZ_PKCRYPT=OFF \
    -DMZ_WZAES=OFF \
    -DMZ_ZSTD=OFF \
    )

pushd "$MINIZLIB_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        # ------------------------ windows, windows64 ------------------------
        windows*)
            load_vsvars

            for arch in sse avx2 arm64 ; do
                platform_target="x64"
                if [[ "$arch" == "arm64" ]]; then
                    platform_target="ARM64"
                fi

                mkdir -p "build_debug_$arch"
                pushd "build_debug_$arch"
                    opts="$(replace_switch /Zi /Z7 $LL_BUILD_DEBUG)"
                    if [[ "$arch" == "avx2" ]]; then
                        opts="$(replace_switch /arch:SSE4.2 /arch:AVX2 $opts)"
                    elif [[ "$arch" == "arm64" ]]; then
                        opts="$(remove_switch /arch:SSE4.2 $opts)"
                    fi
                    plainopts="$(remove_switch /GR $(remove_cxxstd $opts))"

                    cmake $(cygpath -m ${top}/${MINIZLIB_SOURCE_DIR}) -G "$AUTOBUILD_WIN_CMAKE_GEN" -A "$platform_target" \
                        -DCMAKE_CONFIGURATION_TYPES="Debug" \
                        -DCMAKE_C_FLAGS:STRING="$plainopts" \
                        -DCMAKE_CXX_FLAGS:STRING="$opts" \
                        -DCMAKE_MSVC_DEBUG_INFORMATION_FORMAT="Embedded" \
                        "${config[@]}" \
                        -DCMAKE_INSTALL_PREFIX=$(cygpath -m $stage) \
                        -DCMAKE_INSTALL_LIBDIR="$(cygpath -m "$stage/lib/$arch/debug")" \
                        -DZLIB_INCLUDE_DIR="$(cygpath -m "$stage/packages/include/zlib-ng/")" \
                        -DZLIB_LIBRARY="$(cygpath -m "$stage/packages/lib/$arch/debug/zlibd.lib")"

                    cmake --build . --config Debug --parallel $AUTOBUILD_CPU_COUNT

                    # conditionally run unit tests
                    # if [[ "${DISABLE_UNIT_TESTS:-0}" == "0" && "$arch" != "arm64" ]]; then
                    #     ctest -C Debug
                    # fi

                    cmake --install . --config Debug
                popd

                mkdir -p "build_release_$arch"
                pushd "build_release_$arch"
                    opts="$(replace_switch /Zi /Z7 $LL_BUILD_RELEASE)"
                    if [[ "$arch" == "avx2" ]]; then
                        opts="$(replace_switch /arch:SSE4.2 /arch:AVX2 $opts)"
                    elif [[ "$arch" == "arm64" ]]; then
                        opts="$(remove_switch /arch:SSE4.2 $opts)"
                    fi
                    plainopts="$(remove_switch /GR $(remove_cxxstd $opts))"

                    cmake $(cygpath -m ${top}/${MINIZLIB_SOURCE_DIR}) -G "$AUTOBUILD_WIN_CMAKE_GEN" -A "$platform_target" \
                        -DCMAKE_CONFIGURATION_TYPES="Release" \
                        -DCMAKE_C_FLAGS:STRING="$plainopts" \
                        -DCMAKE_CXX_FLAGS:STRING="$opts" \
                        -DCMAKE_MSVC_DEBUG_INFORMATION_FORMAT="Embedded" \
                        "${config[@]}" \
                        -DCMAKE_INSTALL_PREFIX=$(cygpath -m $stage) \
                        -DCMAKE_INSTALL_LIBDIR="$(cygpath -m "$stage/lib/$arch/release")" \
                        -DZLIB_INCLUDE_DIR="$(cygpath -m "$stage/packages/include/zlib-ng/")" \
                        -DZLIB_LIBRARY="$(cygpath -m "$stage/packages/lib/$arch/release/zlib.lib")"

                    cmake --build . --config Release --parallel $AUTOBUILD_CPU_COUNT

                    # conditionally run unit tests
                    # if [[ "${DISABLE_UNIT_TESTS:-0}" == "0" && "$arch" != "arm64" ]]; then
                    #     ctest -C Release
                    # fi

                    cmake --install . --config Release
                popd
            done

            mkdir -p $stage/include/minizip-ng
            mv $stage/include/minizip/*.h "$stage/include/minizip-ng/"
        ;;

        # ------------------------- darwin, darwin64 -------------------------
        darwin*)
            export MACOSX_DEPLOYMENT_TARGET="$LL_BUILD_DARWIN_DEPLOY_TARGET"

            for arch in x86_64 arm64 ; do
                ARCH_ARGS="-arch $arch"
                opts="${TARGET_OPTS:-$ARCH_ARGS $LL_BUILD_RELEASE}"
                cc_opts="$(remove_cxxstd $opts)"
                ld_opts="$ARCH_ARGS"

                mkdir -p "build_$arch"
                pushd "build_$arch"
                    CFLAGS="$cc_opts" \
                    LDFLAGS="$ld_opts" \
                    cmake ${top}/${MINIZLIB_SOURCE_DIR} -G "Xcode" \
                        -DCMAKE_CONFIGURATION_TYPES="Release" \
                        -DCMAKE_C_FLAGS:STRING="$cc_opts" \
                        -DCMAKE_CXX_FLAGS:STRING="$opts" \
                        "${config[@]}" \
                        -DCMAKE_INSTALL_PREFIX="$stage" \
                        -DCMAKE_INSTALL_LIBDIR="$stage/lib/release/$arch" \
                        -DZLIB_INCLUDE_DIR="${stage}/packages/include/zlib-ng/" \
                        -DZLIB_LIBRARY="${stage}/packages/lib/release/libz.a" \
                        -DCMAKE_OSX_ARCHITECTURES="$arch" \
                        -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET}

                    cmake --build . --config Release --parallel $AUTOBUILD_CPU_COUNT

                    # conditionally run unit tests
                    # if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    #     ctest -C Release
                    # fi

                    cmake --install . --config Release
                popd
            done

            lipo -create -output "$stage/lib/release/libminizip.a" "$stage/lib/release/x86_64/libminizip.a" "$stage/lib/release/arm64/libminizip.a"

            mkdir -p $stage/include/minizip-ng
            mv $stage/include/minizip/*.h "$stage/include/minizip-ng/"
        ;;

        # -------------------------- linux, linux64 --------------------------
        linux*)
            for arch in sse avx2 ; do
                # Default target per autobuild build --address-size
                opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE}"
                if [[ "$arch" == "avx2" ]]; then
                    opts="$(replace_switch -march=x86-64-v2 -march=x86-64-v3 $opts)"
                fi

                # Release
                mkdir -p "build_$arch"
                pushd "build_$arch"
                    cmake ${top}/${MINIZLIB_SOURCE_DIR} -G"Ninja" \
                        -DCMAKE_C_FLAGS:STRING="$(remove_cxxstd $opts)" \
                        -DCMAKE_CXX_FLAGS:STRING="$opts" \
                        "${config[@]}" \
                        -DCMAKE_INSTALL_PREFIX=$stage \
                        -DCMAKE_INSTALL_LIBDIR="$stage/lib/$arch/release" \
                        -DZLIB_INCLUDE_DIR="${stage}/packages/include/zlib-ng/" \
                        -DZLIB_LIBRARY="${stage}/packages/lib/$arch/release/libz.a"

                    cmake --build . --config Release --parallel $AUTOBUILD_CPU_COUNT

                    # conditionally run unit tests
                    # if [ "${DISABLE_UNIT_TESTS:-0}" -eq 0 ]; then
                    #     ctest -C Release
                    # fi

                    cmake --install . --config Release

                    mkdir -p $stage/include/minizip-ng
                    mv $stage/include/minizip/*.h "$stage/include/minizip-ng/"
                popd
            done
        ;;
    esac

    mkdir -p "$stage/LICENSES"
    cp ${top}/${MINIZLIB_SOURCE_DIR}/LICENSE "$stage/LICENSES/minizip-ng.txt"
popd

mkdir -p "$stage"/docs/minizip-ng/
cp -a README.Linden "$stage"/docs/minizip-ng/
