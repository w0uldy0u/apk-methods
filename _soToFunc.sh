#!/bin/bash
set -e

BASE_DIR="$1"
shift

OUT_DIR="$BASE_DIR/extracted_so"
FUNC_LIST="$BASE_DIR/jni_methods.txt"

if [[ $# -eq 0 ]]; then
  echo "❌ APK 경로를 지정하세요"
  echo "사용법: $0 some.apk [another.apk ...]"
  exit 1
fi

rm -rf "$OUT_DIR" "$FUNC_LIST"
mkdir -p "$OUT_DIR"

for apk in "$@"; do
  UNZIP_OUTPUT=$((unzip -q -o "$apk" "lib/**/*.so" -d "$OUT_DIR") 2>&1 || true)
  if echo "$UNZIP_OUTPUT" | grep -q "caution: filename not matched"; then
    continue
  fi
done

> "$FUNC_LIST"
for sofile in $(find "$OUT_DIR" -name '*.so'); do
  for sym in $(nm -D --defined-only "$sofile" 2>/dev/null | awk '$2 ~ /^[Tt]$/ {print $3}'); do
    if [[ "$sym" == Java_* ]]; then
      echo "$sym" >> "$FUNC_LIST"
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