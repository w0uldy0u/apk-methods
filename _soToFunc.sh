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

UNZIP_OUTPUT=$( (unzip -q "$APK" "lib/**/*.so" -d "$OUT_DIR") 2>&1 || true )
if echo "$UNZIP_OUTPUT" | grep -q "caution: filename not matched"; then
  echo "⚠️  .so 파일이 없는 APK입니다 (Java-only 앱일 수 있습니다)."
  exit 0
fi

echo "🔍 JNI 네이티브 심볼 추출 중..."
for sofile in $(find "$OUT_DIR" -name '*.so'); do
  nm -D --defined-only "$sofile" 2>/dev/null | awk '{print $3}' \
    | grep '^Java_' \
    | sort -u >> "$FUNC_LIST"
done

echo "✅ 네이티브 함수 목록 → $FUNC_LIST (총 $(wc -l < "$FUNC_LIST")개)"
echo
echo "==================================================="
echo "🎯 랜덤 10개 Native 메서드:"
shuf -n 10 "$FUNC_LIST"
echo "==================================================="

rm -rf "$OUT_DIR"