#!/bin/bash

PACKAGE_NAME="$1"

if [ -z "$PACKAGE_NAME" ]; then
    echo "❌ 사용법: $0 <패키지 키워드>"
    exit 1
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "🔧 adb가 설치되어 있지 않아 설치를 진행합니다..."
  sudo apt update
  sudo apt install -y adb
fi

if ! command -v java >/dev/null 2>&1; then
  echo "☕ Java가 설치되어 있지 않아 설치를 진행합니다..."
  sudo apt update && sudo apt install -y default-jre
fi

PKG=$(adb shell "pm list packages" | grep "$PACKAGE_NAME" | head -n 1 | cut -d: -f2)

PACKAGE_NAME=$PKG

echo "📦 패키지 이름: $PACKAGE_NAME"

BASE_DIR="./$PACKAGE_NAME"
LOCAL_APK="$BASE_DIR/${PACKAGE_NAME}.apk"

mkdir -p "$BASE_DIR"

if [ -f "$LOCAL_APK" ]; then
    echo "📂 APK가 이미 존재함."
else
    echo "📦 패키지 경로 찾는 중..."
    APK_PATH=$(adb shell pm path "$PACKAGE_NAME" | grep '^package:' | grep 'base.apk' | sed 's/package://')

    if [ -z "$APK_PATH" ]; then
        echo "❌ base.apk 경로를 찾을 수 없습니다."
        exit 1
    fi

    echo "✅ APK 경로: $APK_PATH"

    echo "📲 APK 파일 추출 중..."
    adb shell "cp $APK_PATH /sdcard/${PACKAGE_NAME}.apk"
    adb pull "/sdcard/${PACKAGE_NAME}.apk" "$LOCAL_APK"

    if [ ! -f "$LOCAL_APK" ]; then
        echo "❌ APK 파일 추출 실패"
        exit 1
    fi
    echo "✅ APK 파일 추출 완료: $LOCAL_APK"
fi

echo

./_dexToFunc.sh "$BASE_DIR" "$PACKAGE_NAME"
./_soToFunc.sh "$BASE_DIR" "$LOCAL_APK"
