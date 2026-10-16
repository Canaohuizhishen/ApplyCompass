#!/usr/bin/env bash
#
# 投递罗盘 · ApplyCompass —— 一键构建 + 启动
#
# 用法：
#   ./run.sh                       # 增量构建后启动 GUI（默认）
#   ./run.sh --data-dir /tmp/x     # 参数原样透传给 appApplyCompass
#   ./run.sh --import-legacy a.xlsm
#   RUN_SKIP_BUILD=1 ./run.sh      # 跳过构建，直接启动（快速重开）
#
# 构建树 = 仓库内的 build/（与 Qt Creator 的 build/C_C_<Kit>_Release/ 互不干扰）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
BIN="$BUILD_DIR/appApplyCompass"

# —— 并行度：显式限并行（本机纪律：严禁裸 --parallel，曾致全机 OOM）——
# 可用内存 < 8GB 时降到 2，否则用 4。
avail_mb="$(awk '/^MemAvailable:/{print int($2/1024)}' /proc/meminfo)"
JOBS=4
if [ -n "${avail_mb:-}" ] && [ "$avail_mb" -lt 8000 ]; then
    JOBS=2
fi

if [ "${RUN_SKIP_BUILD:-0}" != "1" ]; then
    # 首次未配置则先 configure；之后 Ninja 会在 CMakeLists*.txt 变动时自动重跑 cmake。
    if [ ! -f "$BUILD_DIR/CMakeCache.txt" ]; then
        echo "==> 首次配置：cmake -B build -G Ninja -S ."
        cmake -B "$BUILD_DIR" -G Ninja -S "$ROOT"
    fi
    echo "==> 构建：cmake --build build --parallel $JOBS"
    cmake --build "$BUILD_DIR" --parallel "$JOBS"
fi

echo "==> 启动：$BIN $*"
cd "$BUILD_DIR"
exec "$BIN" "$@"
