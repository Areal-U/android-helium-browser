#!/bin/bash

source common.sh
set_keys

export VERSION=$(grep -m1 -o '[0-9]\+\(\.[0-9]\+\)\{3\}' vanadium/args.gn)
export CHROMIUM_SOURCE=https://chromium.googlesource.com/chromium/src.git
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update

sudo apt-get install -y sudo

sudo apt-get install -y lsb-release

sudo apt-get install -y file

sudo apt-get install -y nano

sudo apt-get install -y git

sudo apt-get install -y curl

sudo apt-get install -y python3

sudo apt-get install -y python3-pillow

sudo apt-get install -y imagemagick

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git

export PATH="$PWD/depot_tools:$PATH"

mkdir -p chromium/src/out/Default

cd chromium

gclient root

cd src

git init

git remote add origin $CHROMIUM_SOURCE

git fetch --depth 1 $CHROMIUM_SOURCE +refs/tags/$VERSION:chromium_$VERSION

git checkout $VERSION

export COMMIT=$(git show-ref -s $VERSION | head -n1)

cat > ../.gclient << EOF
solutions = [{
  "name": "src",
  "url": "$CHROMIUM_SOURCE@$COMMIT",
  "managed": False,
  "custom_deps": {},
  "custom_vars": {
    "checkout_android": True,
  },
}]
EOF

cd ..

gclient sync --nohooks --no-history

cd src

build/install-build-deps.sh --android

gclient runhooks

rm -rf android_webview/browser/aw_field_trial_creator.*

for patch in $SCRIPT_DIR/vanadium/patches/*.patch; do
  sed -i 's/const bool kAlwaysUseOSFilePicker = true;/const bool kAlwaysUseOSFilePicker = false;/' $patch
  sed -i 's/org.grapheneos.vanadium/com.android.chrome/g' $patch
  sed -i 's/Vanadium/Chrome/g' $patch
  sed -i 's/vanadiumium/chromium/g' $patch
  sed -i 's/vanadium/chrome/g' $patch
  sed -i 's/VANADIUM_VERSION/CHROME_VERSION/g' $patch
done

git am $SCRIPT_DIR/vanadium/patches/*.patch

source $SCRIPT_DIR/patch.sh

cp $SCRIPT_DIR/args.gn out/Default/args.gn

mkdir -p out/tmp

mkdir -p out/release

autoninja -C out/Default chrome_public_apk

mv $(find out/Default/apks -name 'Chrome*.apk') out/tmp/$VERSION-arm64-v8a.apk

export PATH=$PWD/third_party/jdk/current/bin/:$PATH

export ANDROID_HOME=$PWD/third_party/android_sdk/public

sign_apk out/tmp/$VERSION-arm64-v8a.apk out/release/$VERSION-arm64-v8a.apk

rm -rf $SCRIPT_DIR/keys
