#!/bin/bash
set -e

BASE_DIR="$1"
PACKAGE_NAME="$2"

DEX_DIR="$BASE_DIR/dex"
LOCAL_APK="$BASE_DIR/${PACKAGE_NAME}.apk"

mkdir -p "$DEX_DIR"
echo "📦 APK에서 DEX 추출 중..."
unzip -j -o "$LOCAL_APK" '*.dex' -d "$DEX_DIR"

[[ -z "$DEX_DIR" || ! -d "$DEX_DIR" ]] && { echo "❌ DEX 폴더 오류"; exit 1; }

BAKSMALI_JAR="baksmali.jar"
if [[ ! -f "$BAKSMALI_JAR" ]]; then
  echo "⬇️  baksmali.jar 다운로드 중…"
  URL=$(curl -sL https://api.github.com/repos/baksmali/smali/releases/latest \
        | grep browser_download_url \
        | grep -E 'baksmali-.*-fat.*\.jar' | head -n1 | cut -d '"' -f 4)
  curl -L "$URL" -o "$BAKSMALI_JAR"
fi

OUT_ROOT="$BASE_DIR/smali_out"
LIST_TXT="$BASE_DIR/java_methods.txt"
rm -rf "$OUT_ROOT"; mkdir -p "$OUT_ROOT"

echo
echo "📂 smali 변환…"
for dex in "$DEX_DIR"/*.dex; do
  [[ -f "$dex" ]] && java -jar "$BAKSMALI_JAR" d "$dex" \
        -o "$OUT_ROOT/$(basename "$dex" .dex)" >/dev/null &
done
wait

echo "🔎 메서드 파싱 중..."
python3 - "$OUT_ROOT" "$LIST_TXT" <<'PY'
import pathlib, sys, os
from concurrent.futures import ThreadPoolExecutor

root = pathlib.Path(sys.argv[1]).resolve()
out = pathlib.Path(sys.argv[2]).open('w')
EXCLUDED_PREFIXES = (
    "android.", "androidx.", "com.android.", "com.google.android.",
    "dalvik.", "java.", "javax.", "kotlin."
)

def extract_methods(smali):
    results = []
    parts = smali.relative_to(root).with_suffix('').parts
    if parts[0].startswith("classes"):
        parts = parts[1:]
    cls = '.'.join(parts)
    if cls.startswith(EXCLUDED_PREFIXES):
        return results

    try:
        with smali.open('r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                line = line.lstrip()
                if not line.startswith(".method"):
                    continue
                tokens = line.split()
                if len(tokens) < 2:
                    continue
                name = tokens[-1].split('(')[0]
                if name == "<init>": name = "$init"
                elif name == "<clinit>": name = "$clinit"
                results.append(f"{cls}.{name}")
    except:
        pass
    return results

smali_files = list(root.rglob('*.smali'))
with ThreadPoolExecutor(max_workers=os.cpu_count()) as executor:
    all_methods = executor.map(extract_methods, smali_files)

flat = set()
for method_list in all_methods:
    flat.update(method_list)

out.writelines(f"{m}\n" for m in sorted(flat))
PY

echo "✅ 자바 함수 목록 → $LIST_TXT (총 $(wc -l < "$LIST_TXT")개)"

echo
echo "==================================================="
echo "🎯 랜덤 10개 JAVA 메서드:"
shuf -n 10 "$LIST_TXT"
echo "==================================================="

rm -rf "$OUT_ROOT" "$DEX_DIR"
echo