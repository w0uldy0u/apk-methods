#!/bin/bash
# dex2frida-ready.sh
#
# 1) baksmali 최신 fat-jar 자동 다운로드
# 2) *.dex → smali
# 3) .method →  <클래스>.<메서드> 형식으로 출력
#    ◦ 멀티-DEX 접두사(classes, classes2…) 제거
#    ◦ <init>/<clinit> → $init/$clinit
#
# 사용: ./dex2frida-ready.sh <dex_폴더>
# ---------------------------------------------------------------

set -e

BASE_DIR="$1"
PACKAGE_NAME="$2"

DEX_DIR="$BASE_DIR/dex"
LOCAL_APK="$BASE_DIR/${PACKAGE_NAME}.apk"

mkdir -p "$DEX_DIR"
echo "📦 APK에서 DEX 추출 중..."
unzip -j "$LOCAL_APK" '*.dex' -d "$DEX_DIR"

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
        -o "$OUT_ROOT/$(basename "$dex" .dex)" >/dev/null
done

python3 - "$OUT_ROOT" "$LIST_TXT" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1]).resolve()
out  = pathlib.Path(sys.argv[2]).open('w')

items = set()
for smali in root.rglob('*.smali'):
    parts = smali.relative_to(root).with_suffix('').parts
    # classes / classes2 … 접두사 제거
    if re.match(r'^classes\d*$', parts[0]): parts = parts[1:]
    cls = '.'.join(parts)
    for line in smali.open():
        m = re.match(r'^\s*\.method\s+(?:[\w\s-]+?\s+)?(\S+)$', line)
        if not m: continue
        name = m.group(1).split('(')[0]
        if   name == '<init>'  : name = '$init'
        elif name == '<clinit>': name = '$clinit'
        items.add(f"{cls}.{name}")
out.write('\n'.join(sorted(items)))
PY

echo "✅ 자바 함수 목록 → $LIST_TXT (총 $(wc -l < "$LIST_TXT")개)"

echo
echo "==================================================="
echo "🎯 랜덤 10개 JAVA 메서드:"
shuf -n 10 "$LIST_TXT"
echo "==================================================="

rm -rf "$OUT_ROOT" "$DEX_DIR"
echo