#!/bin/sh

## WebRTC Android library build script
## Created by modifying iOS script for Android usage

# Configs
DEBUG="${DEBUG:-false}"
BUILD_VP9="${BUILD_VP9:-false}"
BRANCH="${BRANCH:-master}"
ANDROID="${ANDROID:-true}"

OUTPUT_DIR="./out"
COMMON_GN_ARGS="is_debug=${DEBUG} rtc_libvpx_build_vp9=${BUILD_VP9} is_component_build=false rtc_include_tests=false enable_stripping=true enable_dsyms=false"

# Step 1: Download and install depot tools
if [ ! -d depot_tools ]; then
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
else
    cd depot_tools
    git pull origin main
    cd ..
fi
export PATH=$(pwd)/depot_tools:$PATH

# Step 2 - Download and sync WebRTC codebase
if [ ! -d src ]; then
    fetch --nohooks webrtc_android
fi
cd src
git fetch --all
git checkout $BRANCH
gclient sync --with_branch_heads --with_tags
cd ..

# Step 3 - Build Android SDK
build_android() {
    local arch=$1
    local target=$2
    local gen_dir="${OUTPUT_DIR}/android-${arch}"
    local gen_args="${COMMON_GN_ARGS} target_cpu=\"${arch}\" target_os=\"android\""
    gn gen "${gen_dir}" --args="${gen_args}"
    gn args --list ${gen_dir} > ${gen_dir}/gn-args.txt
    ninja -C "${gen_dir}" ${target} || exit 1
}

# Clean previous builds
rm -rf $OUTPUT_DIR

if [ "$ANDROID" = true ]; then
    # Build WebRTC SDK for different Android architectures
    build_android "arm64" "libwebrtc"
    build_android "x86" "libwebrtc"
    build_android "x86_64" "libwebrtc"
    build_android "armeabi-v7a" "libwebrtc"
fi

# Step 4 - Combine the builds into a single AAR or JAR if necessary
combine_libraries() {
    mkdir -p ${OUTPUT_DIR}/combined
    cp ${OUTPUT_DIR}/android-arm64/obj/libwebrtc.a ${OUTPUT_DIR}/combined/
    cp ${OUTPUT_DIR}/android-x86/obj/libwebrtc.a ${OUTPUT_DIR}/combined/
    cp ${OUTPUT_DIR}/android-x86_64/obj/libwebrtc.a ${OUTPUT_DIR}/combined/
    cp ${OUTPUT_DIR}/android-armeabi-v7a/obj/libwebrtc.a ${OUTPUT_DIR}/combined/
    # Combine or package as needed into AAR/JAR
    # Example for packaging AAR:
    # ./gradlew :packageAAR (adjust for actual gradle configuration)
}

combine_libraries

# Step 5 - Optional: Package into AAR, create metadata, archive SDK, etc.
NOW=$(date -u +"%Y-%m-%dT%H-%M-%S")
OUTPUT_NAME=WebRTC-Android-$NOW.zip
cd $OUTPUT_DIR
zip -r $OUTPUT_NAME combined/
cd ..

# Step 6 - Calculate SHA256 checksum
CHECKSUM=$(shasum -a 256 ${OUTPUT_DIR}/$OUTPUT_NAME | awk '{ print $1 }')
COMMIT_HASH=$(git rev-parse HEAD)

echo "{ \"file\": \"${OUTPUT_NAME}\", \"checksum\": \"${CHECKSUM}\", \"commit\": \"${COMMIT_HASH}\", \"branch\": \"${BRANCH}\" }" > metadata.json
cat metadata.json
