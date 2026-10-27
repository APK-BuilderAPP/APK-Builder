#!/usr/bin/env bash
# ============================================================================
# APK Builder —— Smali 工程打包脚本
#
# 说明：仓库 bin/ 内置的是「安卓端运行时」工具链（arm 版 aapt + dex 格式
#       smali/apksigner），它们来自手机端 APK Builder，供安卓环境集成使用。
#       PC 端若要跑通本脚本，需把 bin/ 里的工具替换为 JVM/桌面版：
#         - bin/smali.jar      → 替换为 PC 版 smali（含 Main-Class）
#         - bin/apksigner.jar  → 替换为 SDK build-tools 里的 apksigner.jar
#         - bin/arm_aapt       → 替换为对应平台（x86_64/win）的 aapt
#       脚本会在启动时自动检测，缺失/不匹配则给出明确提示。
#
# 用法：./build.sh [-i 输入工程] [-o 输出APK] [-p 包名] [-n 应用名] [-k key名]
# 示例：./build.sh -i template -p com.example.demo -n "我的应用"
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/bin"
KEYS="$SCRIPT_DIR/keys"

# ---------------- 默认值 ----------------
INPUT_DIR="${INPUT_DIR:-$SCRIPT_DIR/template}"
OUTPUT_APK="${OUTPUT_APK:-$SCRIPT_DIR/dist/app-release.apk}"
PKG_NAME="${PKG_NAME:-com.apkbuilder.demo}"
APP_NAME="${APP_NAME:-APK Builder}"
KEY_NAME="${KEY_NAME:-testkey}"
DEBUG="${DEBUG:-0}"

# ---------------- 解析参数 ----------------
while getopts "i:o:p:n:k:d" opt; do
  case "$opt" in
    i) INPUT_DIR="$OPTARG" ;;
    o) OUTPUT_APK="$OPTARG" ;;
    p) PKG_NAME="$OPTARG" ;;
    n) APP_NAME="$OPTARG" ;;
    k) KEY_NAME="$OPTARG" ;;
    d) DEBUG=1 ;;
    *) echo "未知参数: -$OPTARG"; exit 1 ;;
  esac
done

# ---------------- 工具链自检 ----------------
echo "===== 工具链自检 ====="
command -v java >/dev/null 2>&1 && echo "[OK] java: $(java -version 2>&1 | head -1)" || { echo "[错误] 未找到 java"; exit 1; }

check_jvm_jar() { # 参数: 文件名
  local f="$1"
  [ -f "$BIN/$f" ] || { echo "[错误] 缺少 $BIN/$f"; return 1; }
  # 检测是否为 DEX 打包（安卓端版本，JVM 无法直接运行）
  if unzip -l "$BIN/$f" 2>/dev/null | grep -q "classes.dex" && ! unzip -l "$BIN/$f" 2>/dev/null | grep -q "\.class"; then
    echo "[警告] $f 为 DEX 格式（安卓端运行时版），PC 端需替换为 JVM 版后才能由本脚本驱动。"
    return 1
  fi
  echo "[OK] $f"
  return 0
}

check_bin() { # 参数: 文件名
  local f="$1"
  [ -f "$BIN/$f" ] || { echo "[错误] 缺少 $BIN/$f"; return 1; }
  if file "$BIN/$f" 2>/dev/null | grep -q "ARM"; then
    echo "[警告] $f 为 ARM 二进制（安卓端版），当前平台可能无法执行，需替换为对应平台 aapt。"
    return 1
  fi
  echo "[OK] $f"
  return 0
}

PC_READY=1
check_bin arm_aapt      || PC_READY=0
check_jvm_jar smali.jar || PC_READY=0
check_jvm_jar apksigner.jar || PC_READY=0
[ -f "$BIN/android.jar" ] && echo "[OK] android.jar" || { echo "[错误] 缺少 android.jar"; PC_READY=0; }
[ -f "$KEYS/$KEY_NAME.pk8" ] && [ -f "$KEYS/$KEY_NAME.x509.pem" ] || { echo "[错误] 缺少签名 key: $KEY_NAME"; PC_READY=0; }

if [ "$PC_READY" != "1" ]; then
  echo ""
  echo "===== 检测结果：当前 bin/ 为安卓端运行时工具链，无法在 PC JVM 直接构建 ====="
  echo "可选做法："
  echo "  ① 在安卓环境（手机/模拟器/ART）中集成并使用这套工具链；"
  echo "  ② 在 PC 端替换为桌面版工具（aapt / smali / apksigner 的 JVM 版）后重跑本脚本。"
  echo "  详见 docs/BUILD_GUIDE.md 第 6 节。"
  exit 2
fi

# ---------------- 构建 ----------------
BUILD_DIR="$SCRIPT_DIR/.build"
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR" "$(dirname "$OUTPUT_APK")"

echo "[1/5] 渲染模板 (包名=$PKG_NAME, 应用名=$APP_NAME)"
cp -r "$INPUT_DIR"/. "$BUILD_DIR"/
[ -f "$BUILD_DIR/AndroidManifest.xml" ] && {
  sed -i "s/{{PACKAGE}}/$PKG_NAME/g; s/{{APP_NAME}}/$APP_NAME/g" "$BUILD_DIR/AndroidManifest.xml"
}
[ -f "$BUILD_DIR/res/values/strings.xml" ] && {
  sed -i "s/{{APP_NAME}}/$APP_NAME/g" "$BUILD_DIR/res/values/strings.xml"
}

echo "[2/5] 编译资源 (aapt)"
"$BIN/arm_aapt" package -f -m \
  -S "$BUILD_DIR/res" -J "$BUILD_DIR/gen" \
  -M "$BUILD_DIR/AndroidManifest.xml" -I "$BIN/android.jar"

echo "[3/5] Smali -> Dex"
java -jar "$BIN/smali.jar" assemble "$BUILD_DIR/smali" -o "$BUILD_DIR/classes.dex"

echo "[4/5] 组装未签名 APK"
UNSIGNED="$BUILD_DIR/unsigned.apk"
rm -f "$UNSIGNED"
"$BIN/zip" -j "$UNSIGNED" "$BUILD_DIR/AndroidManifest.xml" "$BUILD_DIR/classes.dex" >/dev/null
[ -f "$BUILD_DIR/resources.ap_" ] && (cd "$BUILD_DIR" && "$BIN/zip" -r -u "$UNSIGNED" resources.ap_ res >/dev/null 2>&1 || true)

echo "[5/5] 签名 (apksigner)"
java -jar "$BIN/apksigner.jar" sign \
  --key "$KEYS/$KEY_NAME.pk8" --cert "$KEYS/$KEY_NAME.x509.pem" \
  --out "$OUTPUT_APK" "$UNSIGNED"

echo ""
echo "构建完成 ✅  输出: $OUTPUT_APK  包名: $PKG_NAME  应用名: $APP_NAME  签名: $KEY_NAME"
echo "校验: java -jar $BIN/apksigner.jar verify --verbose $OUTPUT_APK"

[ "$DEBUG" = "1" ] && { echo ""; echo "----- 中间产物 ($BUILD_DIR) -----"; find "$BUILD_DIR" -maxdepth 3 -type f | sed "s|$BUILD_DIR/||" | sort; }
