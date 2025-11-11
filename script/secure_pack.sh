#!/usr/bin/env bash
# secure_pack.sh — Create or update encrypted 7z archive with date suffix
# Author: Ethan(cshengs1994@gmail.com)
# Version: 1.0
#
# How to use: 
#   To create a new archive:
#     ./secure_pack.sh new <source_path> [prefix]
#   To update an existing archive:
#     ./secure_pack.sh update <existing_archive.7z> <files_to_add...>
#

set -euo pipefail

# === 检查 7z 命令 ===
if ! command -v 7z >/dev/null 2>&1; then
  echo "❌ Error: 7z command not found. Please install p7zip or 7zip first."
  echo "   macOS: brew install p7zip"
  echo "   Ubuntu: sudo apt install p7zip-full"
  exit 1
fi

# === 检查参数 ===
if [[ $# -lt 2 ]]; then
  echo "Usage:"
  echo "  $0 new <source_path> [prefix]"
  echo "  $0 update <existing_archive.7z> <files_to_add...>"
  exit 1
fi

MODE="$1"
shift

# === 输入密码 ===
read -s -p "Enter password: " PASS
echo
if [[ -z "$PASS" ]]; then
  echo "❌ Password empty — aborted."
  exit 2
fi

# === 生成时间戳 ===
TS=$(date +"%Y-%m-%d_%H%M%S")

# ===============================================================
# 模式 1：新建压缩包
# ===============================================================
if [[ "$MODE" == "new" ]]; then
  SRC="$1"
  PREFIX="${2:-Archive}"
  if [[ ! -e "$SRC" ]]; then
    echo "❌ Source not found: $SRC"
    exit 3
  fi

  OUT="${PREFIX}_${TS}.7z"
  echo "📦 Creating archive: $OUT"
  7z a -t7z -mx=7 -mhe=on -p"$PASS" "$OUT" "$SRC"
  echo "✅ Done! -> $OUT"
  exit 0
fi

# ===============================================================
# 模式 2：更新已有压缩包
# ===============================================================
if [[ "$MODE" == "update" ]]; then
  ARCHIVE="$1"
  shift
  ADD_ITEMS=( "$@" )

  if [[ ! -f "$ARCHIVE" ]]; then
    echo "❌ Archive not found: $ARCHIVE"
    exit 4
  fi

  echo "🔍 Testing archive integrity..."
  if ! 7z t "$ARCHIVE" -p"$PASS" >/dev/null 2>&1; then
    echo "❌ Invalid password or corrupted archive!"
    exit 5
  fi

  TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/repack.XXXXXX")
  trap 'rm -rf "$TMPDIR"' EXIT

  echo "📂 Extracting $ARCHIVE → $TMPDIR"
  7z x "$ARCHIVE" -p"$PASS" -o"$TMPDIR" >/dev/null

  echo "➕ Adding new files..."
  for ITEM in "${ADD_ITEMS[@]}"; do
    if [[ -e "$ITEM" ]]; then
      cp -a "$ITEM" "$TMPDIR"/
    else
      echo "⚠️  Warning: $ITEM not found, skipped."
    fi
  done

  BASE=$(basename "$ARCHIVE" .7z)
  DIR=$(dirname "$ARCHIVE")
  NEW="${DIR}/${BASE}_${TS}.7z"
  BACKUP="${ARCHIVE}.bak_$(date +%Y%m%d_%H%M%S)"

  echo "💾 Backing up original archive → $BACKUP"
  mv "$ARCHIVE" "$BACKUP"

  echo "🧩 Repacking new archive: $NEW"
  7z a -t7z -mx=7 -mhe=on -p"$PASS" "$NEW" "$TMPDIR"/*

  echo "✅ Update complete!"
  echo "   New archive: $NEW"
  echo "   Backup kept: $BACKUP"

  rm -rf "$TMPDIR"
  trap - EXIT
  exit 0
fi

# ===============================================================
# 未知模式
# ===============================================================
echo "❌ Unknown mode: $MODE"
echo "Use: new | update"
exit 6
