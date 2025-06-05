#!/bin/bash

PACKAGE_NAME="$1"

if [ -z "$PACKAGE_NAME" ]; then
    echo "❌ 사용법: $0 <패키지 키워드>"
    exit 1
fi

if ! command -v java >/dev/null 2>&1; then
  echo "☕ Java가 설치되어 있지 않아 설치를 진행합니다..."
  sudo apt update && sudo apt install -y default-jre
fi

if ! command -v adb >/dev/null 2>&1; then
    echo "🔧 adb가 설치되어 있지 않아 설치를 진행합니다..."
    sudo apt update
    sudo apt install -y android-tools-adb
fi

PKG=$(adb shell "pm list packages" | grep "$PACKAGE_NAME" | head -n 1 | cut -d: -f2)
PACKAGE_NAME=$PKG
BASE_DIR="./$PACKAGE_NAME"
mkdir -p "$BASE_DIR"

echo "📦 패키지 이름: $PACKAGE_NAME"

APK_PATHS=$(adb shell pm path "$PACKAGE_NAME" | grep '^package:' | sed 's/package://')

if [ -z "$APK_PATHS" ]; then
    echo "❌ APK 경로를 찾을 수 없습니다."
    exit 1
fi

INDEX=1
APK_FILES=()

for path in $APK_PATHS; do
    FILENAME="${PACKAGE_NAME}_part${INDEX}.apk"
    LOCAL_APK="$BASE_DIR/$FILENAME"
    echo "📲 추출 중: $path → $LOCAL_APK"
    adb shell "cp $path /sdcard/$FILENAME"
    adb pull "/sdcard/$FILENAME" "$LOCAL_APK"
    APK_FILES+=("$LOCAL_APK")
    ((INDEX++))
done

echo "✅ APK 파일 총 ${#APK_FILES[@]}개 추출 완료."

./_dexToFunc.sh "$BASE_DIR" "${APK_FILES[@]}"
./_soToFunc.sh "$BASE_DIR" "${APK_FILES[@]}"