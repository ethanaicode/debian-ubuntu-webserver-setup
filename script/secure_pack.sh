#!/usr/bin/env bash
# secure_pack.sh — Create or update encrypted 7z archive with date suffix
# Author: Ethan(cshengs1994@gmail.com)
# Version: 1.2
# Usage:
#   To create new archive:
#     ./secure_pack.sh new <sources...> [--out output_archive.7z]
#   To update existing archive:
#     ./secure_pack.sh update <existing_archive.7z> <files_to_add...>
#   To list archive contents:
#     ./secure_pack.sh list <archive.7z>
#   To extract archive:
#     ./secure_pack.sh extract <archive.7z> [--out output_dir]

set -euo pipefail

# === 检查 7z 命令 ===
if ! command -v 7z >/dev/null 2>&1; then
  echo "❌ Error: 7z command not found. Please install p7zip or 7zip first."
  echo "   macOS: brew install p7zip"
  echo "   Ubuntu: sudo apt install p7zip-full"
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage:"
  echo "  $0 new <sources...> [--out output_archive.7z]"
  echo "  $0 update <existing_archive.7z> <files_to_add...>"
  echo "  $0 list <archive.7z>"
  echo "  $0 extract <archive.7z> [--out output_dir]"
  exit 1
fi

MODE="$1"; shift

# === 对于 list 模式，不需要其他参数检查 ===
if [[ "$MODE" == "list" ]]; then
  [[ $# -lt 1 ]] && { echo "Usage: $0 list <archive.7z>"; exit 1; }
  ARCHIVE="$1"
  [[ ! -f "$ARCHIVE" ]] && { echo "❌ Archive not found: $ARCHIVE"; exit 4; }
  
  read -s -p "Enter password: " PASS
  echo
  [[ -z "$PASS" ]] && { echo "❌ Password empty — aborted."; exit 2; }
  
  echo "📋 Listing contents of: $ARCHIVE"
  if ! 7z l "$ARCHIVE" -p"$PASS"; then
    echo "❌ Invalid password or corrupted archive!"
    exit 5
  fi
  exit 0
fi

# === 通用时间戳 ===
TS=$(date +"%Y-%m-%d_%H%M%S")

# === 解析参数 ===
OUT_PATH=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      OUT_PATH="$2"
      shift 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done
set -- "${ARGS[@]}"

# === 输入密码 ===
read -s -p "Enter password: " PASS
echo
[[ -z "$PASS" ]] && { echo "❌ Password empty — aborted."; exit 2; }

# ===============================================================
# 🆕 模式 1：创建新压缩包
# 提示：如果压缩时不希望包含根目录，最稳的做法是先进入对应目录再打包
# ===============================================================
if [[ "$MODE" == "new" ]]; then
  [[ $# -lt 1 ]] && { echo "Usage: $0 new <sources...> [--out output.7z]"; exit 1; }

  # 若未指定输出文件及路径，则自动在当前目录创建 Archive_时间戳.7z 文件
  if [[ -z "$OUT_PATH" ]]; then
    OUT_PATH="./Archive_${TS}.7z"
  fi

  OUT_DIR=$(dirname "$OUT_PATH")
  mkdir -p "$OUT_DIR"

  echo "📦 Creating archive: $OUT_PATH"

  # 展开所有路径/通配符
  EXPANDED=()
  for item in "$@"; do
    # 先检查文件是否直接存在（支持带空格的文件名）
    if [[ -e "$item" || -d "$item" ]]; then
      EXPANDED+=("$item")
    else
      # 如果文件不存在，尝试通配符展开
      shopt -s nullglob
      matches=($item)  # 不使用 eval，避免空格问题
      shopt -u nullglob
      
      if [[ ${#matches[@]} -eq 0 ]]; then
        echo "⚠️  Warning: $item not found"
      else
        EXPANDED+=("${matches[@]}")
      fi
    fi
  done

  [[ ${#EXPANDED[@]} -eq 0 ]] && { echo "❌ No valid sources to pack."; exit 3; }

  # 创建压缩包
  7z a -t7z -mx=0 -mhe=on -p"$PASS" "$OUT_PATH" "${EXPANDED[@]}"
  echo "✅ Done! -> $OUT_PATH"
  exit 0
fi

# ===============================================================
# 🔁 模式 2：更新已有压缩包
# 默认情况使用原始文件名加时间戳来命名新压缩包
# 如果你想按照自己的命名规则，可以修改 BASE 和 NEW_PATH 变量的定义
# ===============================================================
if [[ "$MODE" == "update" ]]; then
  [[ $# -lt 2 ]] && { echo "Usage: $0 update <archive.7z> <files_to_add...>"; exit 1; }

  ARCHIVE="$1"
  shift
  [[ ! -f "$ARCHIVE" ]] && { echo "❌ Archive not found: $ARCHIVE"; exit 4; }

  echo "🔍 Testing archive..."
  if ! 7z t "$ARCHIVE" -p"$PASS" >/dev/null 2>&1; then
    echo "❌ Invalid password or corrupted archive!"
    exit 5
  fi

  TMPDIR=$(mktemp -d /tmp/repack.XXXXXX)
  trap 'rm -rf "$TMPDIR"' EXIT

  echo "📂 Extracting..."
  7z x "$ARCHIVE" -p"$PASS" -o"$TMPDIR" >/dev/null

  echo "➕ Adding new files..."
  for item in "$@"; do
    # 先检查文件是否直接存在（支持带空格的文件名）
    if [[ -e "$item" || -d "$item" ]]; then
      echo "  Adding: $item"
      cp -a "$item" "$TMPDIR"/
    else
      # 如果文件不存在，尝试通配符展开
      shopt -s nullglob
      matches=($item)  # 不使用 eval，避免空格问题
      shopt -u nullglob
      
      if [[ ${#matches[@]} -eq 0 ]]; then
        echo "⚠️  Warning: $item not found, skipping..."
      else
        for match in "${matches[@]}"; do
          echo "  Adding: $match"
          cp -a "$match" "$TMPDIR"/
        done
      fi
    fi
  done

  BASE=$(basename "$ARCHIVE" .7z)
  ARCHIVE_DIR=$(dirname "$ARCHIVE")
  NEW_PATH="${ARCHIVE_DIR}/${BASE}_${TS}.7z"

  echo "🧩 Repacking new archive: $NEW_PATH"
  (cd "$TMPDIR" && 7z a -t7z -mx=0 -mhe=on -p"$PASS" "$NEW_PATH" ./*)
  echo "✅ Update complete! → $NEW_PATH"

  rm -rf "$TMPDIR"
  trap - EXIT
  exit 0
fi

# ===============================================================
# 📦 模式 3：解压压缩包
# ===============================================================
if [[ "$MODE" == "extract" ]]; then
  [[ $# -lt 1 ]] && { echo "Usage: $0 extract <archive.7z> [--out output_dir]"; exit 1; }
  
  ARCHIVE="$1"
  shift
  [[ ! -f "$ARCHIVE" ]] && { echo "❌ Archive not found: $ARCHIVE"; exit 4; }

  # 解析输出目录参数
  OUT_DIR=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out)
        OUT_DIR="$2"
        shift 2
        ;;
      *)
        echo "❌ Unknown parameter: $1"
        exit 1
        ;;
    esac
  done

  # 如果未指定输出目录，使用当前目录
  if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="."
  fi

  # 确保输出目录存在
  mkdir -p "$OUT_DIR"

  read -s -p "Enter password: " PASS
  echo
  [[ -z "$PASS" ]] && { echo "❌ Password empty — aborted."; exit 2; }

  echo "🔍 Testing archive..."
  if ! 7z t "$ARCHIVE" -p"$PASS" >/dev/null 2>&1; then
    echo "❌ Invalid password or corrupted archive!"
    exit 5
  fi

  echo "📂 Extracting to: $OUT_DIR"
  7z x "$ARCHIVE" -p"$PASS" -o"$OUT_DIR"
  echo "✅ Extraction complete!"
  exit 0
fi

echo "❌ Unknown mode: $MODE"
exit 6