#!/bin/bash
# ⬇️ APK에서 .so 추출 → JNI 네이티브 함수명(Java_…) 출력

set -e

BASE_DIR="$1"
APK="$2"

OUT_DIR="$BASE_DIR/extracted_so"
FUNC_LIST="$BASE_DIR/jni_methods.txt"

if [[ -z "$APK" || ! -f "$APK" ]]; then
  echo "❌ APK 경로를 지정하세요"
  echo "사용법: ./extract_so_frida_jni.sh some.apk"
  exit 1
fi

echo "📦 APK에서 .so 추출 중..."
rm -rf "$OUT_DIR" "$FUNC_LIST"
mkdir -p "$OUT_DIR"

UNZIP_OUTPUT=$( (unzip -q -o "$APK" "lib/**/*.so" -d "$OUT_DIR") 2>&1 || true )
if echo "$UNZIP_OUTPUT" | grep -q "caution: filename not matched"; then
  echo "⚠️  .so 파일이 없는 APK입니다 (Java-only 앱일 수 있습니다)."
  rm -rf "$OUT_DIR"
  exit 0
fi

echo "🔍 JNI 네이티브 심볼 추출 중..."
> "$FUNC_LIST"

for sofile in $(find "$OUT_DIR" -name '*.so'); do
  echo "📦 처리 중: $sofile"

  # nm 결과에서: 타입이 'T', 't'인 심볼만 추출
  nm -D --defined-only "$sofile" 2>/dev/null | awk '$2 ~ /^[Tt]$/ {print $3}' | while read sym; do
    # Java JNI
    if [[ "$sym" == Java_* ]]; then
      echo "$sym" >> "$FUNC_LIST"
    # C/C++ 네이티브 함수
    elif [[ "$sym" == JNI_* || "$sym" == native_* || "$sym" == _Z* ]]; then
      if [[ "$sym" != _ZTV* && "$sym" != _ZTI* && "$sym" != _ZTS* && "$sym" != _ZTT* ]]; then
        echo "$sym" >> "$FUNC_LIST"
      fi
    fi
  done
done

sort -u "$FUNC_LIST" -o "$FUNC_LIST"

echo "✅ 네이티브 함수 목록 → $FUNC_LIST (총 $(wc -l < "$FUNC_LIST")개)"
echo
echo "==================================================="
echo "🎯 랜덤 10개 Native 메서드:"
shuf -n 10 "$FUNC_LIST"
echo "==================================================="

rm -rf "$OUT_DIR"