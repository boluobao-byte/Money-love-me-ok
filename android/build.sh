#!/usr/bin/env bash
# 小荷包 Android 外壳构建脚本（不依赖 Gradle，直接用 build-tools）
# 依赖：JDK 17、Android SDK 的 platforms/android-34 与 build-tools/34.0.0
# 用法：ANDROID_SDK_ROOT=/opt/android-sdk ./build.sh
set -euo pipefail

cd "$(dirname "$0")/app/src/main"

SDK="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
BT="$SDK/build-tools/34.0.0"
PLATFORM="$SDK/platforms/android-34/android.jar"
VERSION_NAME="${VERSION_NAME:-1.0.0}"
VERSION_CODE="${VERSION_CODE:-1}"
OUT="build"
APK="../../../pocket-${VERSION_NAME}.apk"

for f in "$BT/aapt2" "$BT/d8" "$BT/zipalign" "$BT/apksigner" "$PLATFORM"; do
  [ -e "$f" ] || { echo "缺少构建工具：$f" >&2; exit 1; }
done

rm -rf "$OUT"
mkdir -p "$OUT/compiled" "$OUT/gen" "$OUT/classes" "$OUT/dex" ../../../keystore
KEYSTORE="../../../keystore/pocket.jks"

# 1. 编译资源
"$BT/aapt2" compile --dir res -o "$OUT/compiled/res.zip"

# 2. 链接资源 + 生成 R.java
"$BT/aapt2" link \
  -o "$OUT/base.apk" \
  -I "$PLATFORM" \
  --manifest AndroidManifest.xml \
  --java "$OUT/gen" \
  --min-sdk-version 23 \
  --target-sdk-version 34 \
  --version-code "$VERSION_CODE" \
  --version-name "$VERSION_NAME" \
  "$OUT/compiled/res.zip"

# 3. 编译 Java（target 8，d8 直接支持）
find java -name '*.java' > "$OUT/sources.txt"
find "$OUT/gen" -name '*.java' >> "$OUT/sources.txt"
javac -encoding UTF-8 -source 8 -target 8 -Xlint:-options \
  -classpath "$PLATFORM" -d "$OUT/classes" @"$OUT/sources.txt"

# 4. 转 dex
find "$OUT/classes" -name '*.class' > "$OUT/classes.txt"
"$BT/d8" --lib "$PLATFORM" --min-api 23 --output "$OUT/dex" @"$OUT/classes.txt"

# 5. 打包 + 对齐 + 签名
cp "$OUT/base.apk" "$OUT/unsigned.apk"
zip -q -j "$OUT/unsigned.apk" "$OUT/dex/classes.dex"
"$BT/zipalign" -f 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"

if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -keystore "$KEYSTORE" -alias pocket \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass pocket123456 -keypass pocket123456 \
    -dname "CN=Pocket, OU=Personal, O=Qiuli55, L=Shanghai, ST=Shanghai, C=CN" >/dev/null 2>&1
fi

"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass pass:pocket123456 \
  --key-pass pass:pocket123456 --out "$APK" "$OUT/aligned.apk"

"$BT/apksigner" verify "$APK" >/dev/null
echo "APK 已生成：$(cd "$(dirname "$APK")" && pwd)/$(basename "$APK")"
ls -lh "$APK"
