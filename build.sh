#!/bin/bash

set -e

APP_MODULE=app
ARCHIVES_BASE_NAME=${APP_MODULE}
FLAVOR=standard

# Set up environment.
ANDROID_HOME=${HOME}/Android/Sdk
ANDROID_BUILD_TOOLS_VERSION=28.0.3
ANDROID_BUILD_TOOLS=${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}
ANDROID_PLATFORM_TOOLS=${ANDROID_HOME}/platform-tools

# Keystore
APP_KEYSTORE=app.keystore
APP_KEYSTORE_PASSWORD=android

R8_SIGNED_APK=none
for SHRINKER in r8 r8full proguard; do
  OUT=out/${SHRINKER}
  mkdir -p ${OUT}

  git checkout gradle.properties
  if [ "${SHRINKER}" = "r8full" ]; then
    echo -e "\nandroid.enableR8.fullMode=true\n" >> gradle.properties
  fi
  if [ "${SHRINKER}" = "proguard" ]; then
    echo -e "\nandroid.enableR8=false\n" >> gradle.properties
  fi
  cat gradle.properties

  # Build release.
  ANDROID_HOME=${ANDROID_HOME} ./gradlew clean :${APP_MODULE}:assembleRelease

  # Sign release build.
  if [ -z "${FLAVOR}" ]; then
    UNSIGNED_APK=${APP_MODULE}/build/outputs/apk/release/${ARCHIVES_BASE_NAME}-release-unsigned.apk
  else
    UNSIGNED_APK=${APP_MODULE}/build/outputs/apk/${FLAVOR}/release/${ARCHIVES_BASE_NAME}-${FLAVOR}-release-unsigned.apk
  fi

  ALIGNED_APK=${OUT}/${ARCHIVES_BASE_NAME}-release-unsigned-aligned.apk
  SIGNED_APK=${OUT}/${ARCHIVES_BASE_NAME}-release.apk

  ${ANDROID_BUILD_TOOLS}/zipalign -f 4 ${UNSIGNED_APK} ${ALIGNED_APK}
  ${ANDROID_BUILD_TOOLS}/apksigner sign -v --ks ${APP_KEYSTORE} --ks-pass pass:${APP_KEYSTORE_PASSWORD} --min-sdk-version 19 --out ${SIGNED_APK} ${ALIGNED_APK}

  if [ "${SHRINKER}" = "r8" ]; then
    R8_SIGNED_APK=${SIGNED_APK}
  fi

  unzip ${SIGNED_APK} *.dex -d ${OUT}
done
git checkout gradle.properties

ls -Rl out

# Install on emulator and device.
${ANDROID_PLATFORM_TOOLS}/adb -e install ${R8_SIGNED_APK}
${ANDROID_PLATFORM_TOOLS}/adb -d install ${R8_SIGNED_APK}
