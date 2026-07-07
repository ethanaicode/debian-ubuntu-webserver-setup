#!/bin/zsh

set -euo pipefail

# 最小配置区：未来要扩展时，优先改这里
SCRIPT_DIR="${0:A:h}"
SOURCE_DIR="${RECOVER_SOURCE_DIR:-$SCRIPT_DIR/.ssh}"
TARGET_DIR="$HOME/.ssh"
KNOWN_HOSTS_FILE="$TARGET_DIR/known_hosts"
HOSTS_LIST_FILE="$SOURCE_DIR/known_hosts_hosts.txt"

DEFAULT_HOSTS=(
	github.com
)

log() {
	print -r -- "[recover] $1"
}

warn() {
	print -u2 -r -- "[recover] warning: $1"
}

prepare_target() {
	mkdir -p "$TARGET_DIR"
	chmod 700 "$TARGET_DIR"

	touch "$KNOWN_HOSTS_FILE"
	chmod 600 "$KNOWN_HOSTS_FILE"
}

copy_if_exists() {
	local name="$1"
	local src="$SOURCE_DIR/$name"
	local dst="$TARGET_DIR/$name"

	if [[ -f "$src" ]]; then
		cp -v "$src" "$dst"
		case "$name" in
			*.pub|known_hosts)
				chmod 644 "$dst"
				;;
			*)
				chmod 600 "$dst"
				;;
		esac
	fi
}

restore_ssh_files() {
	if [[ ! -d "$SOURCE_DIR" ]]; then
		warn "未找到源目录: $SOURCE_DIR"
		warn "请在脚本同级目录准备 .ssh 目录，或设置 RECOVER_SOURCE_DIR。"
		return 0
	fi

	log "恢复 SSH 文件..."

	copy_if_exists "id_ed25519"
	copy_if_exists "id_ed25519.pub"
	copy_if_exists "id_rsa"
	copy_if_exists "id_rsa.pub"
	copy_if_exists "config"
	copy_if_exists "known_hosts"
}

append_known_host() {
	local host="$1"

	[[ -n "$host" ]] || return 0

	if ssh-keygen -F "$host" -f "$KNOWN_HOSTS_FILE" >/dev/null 2>&1; then
		log "known_hosts 已存在: $host"
		return 0
	fi

	if ssh-keyscan -H -t ed25519 "$host" >> "$KNOWN_HOSTS_FILE" 2>/dev/null; then
		log "已写入指纹: $host"
		return 0
	fi

	warn "获取指纹失败: $host"
	return 0
}

restore_known_hosts() {
	log "预写 known_hosts..."

	local host
	for host in "${DEFAULT_HOSTS[@]}"; do
		append_known_host "$host"
	done

	if [[ -f "$HOSTS_LIST_FILE" ]]; then
		while IFS= read -r host; do
			[[ -z "$host" || "$host" == \#* ]] && continue
			append_known_host "$host"
		done < "$HOSTS_LIST_FILE"
	fi
}

main() {
	log "开始恢复 SSH 数据"
	log "源目录: $SOURCE_DIR"

	prepare_target
	restore_ssh_files
	restore_known_hosts

	log "恢复完成"
	log "可执行检查: ls -al ~/.ssh && ssh -T git@github.com"
}

main "$@"
