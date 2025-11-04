#!/usr/bin/env bash

# 脚本作用: 自动同步 certbot 生成的证书到指定目录，并重启 nginx
#     会自动调用 certbot renew 来更新证书，如果有更新，则自动同步到指定目录
#     通过定时任务，可以实现证书的自动更新和同步
# 注意：certbot 安装后默认会会自动创建一个定时任务来更新证书，这会导致本脚本失效（无法触发 deploy-hook）。
#     因此请禁用 certbot 自带的定时任务：
#         sudo systemctl disable --now certbot.timer
#         sudo vim /etc/cron.d/certbot
#     当然你也可以保留 certbot 自带的定时任务，不过需要修改配置以调用本脚本（不推荐）：
#         在 /etc/letsencrypt/cli.ini 或者 /etc/letsencrypt/renewal/yourdomain.conf 中添加：
#         renew_hook = /path/to/this/script/auto_certbot_sync.sh --deploy

set -euo pipefail

#####################################
# 可配置区
#####################################

# 如果留空则自动定位为 /etc/letsencrypt/live
: "${LIVE_PATH:=/etc/letsencrypt/live}"

# 你期望证书复制到的目录根（提供默认值）
CERT_PATH="${CERT_PATH:-/www/vhost/cert}"

# live 目录名与目标证书目录名的映射（等长数组）
# 例：/etc/letsencrypt/live/example.com -> /www/vhost/cert/example.com
keys=("example.com")
values=("example.com")

# 日志文件
LOG_FILE="/www/wwwlogs/certbot-auto.log"

# Nginx 可执行文件路径（若系统不在 PATH，可手动指定绝对路径）
NGINX_BIN="${NGINX_BIN:-nginx}"

#####################################
# 工具函数
#####################################

log() {
  local ts msg
  ts="$(date '+%F %T')"
  msg="$*"
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "[$ts] $msg" | tee -a "$LOG_FILE" >/dev/null
}

fail() {
  log "ERROR: $*"
  exit 1
}

ensure_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    fail "请以 root 身份运行。"
  fi
}

find_map_value() {
  # 输入：$1 = key（live 目录名），输出：echo 匹配到的目标目录名；没找到则空
  local k="$1"
  local i
  for ((i=0; i<${#keys[@]}; i++)); do
    if [[ "${keys[$i]}" == "$k" ]]; then
      echo "${values[$i]}"
      return 0
    fi
  done
  echo ""
}

copy_cert() {
  # 输入：$1 = 源 live 目录名（basename），$2 = 目标目录名
  local src_basename="$1"
  local dst_basename="$2"

  local src_dir="$LIVE_PATH/$src_basename"
  local dst_dir="$CERT_PATH/$dst_basename"

  [[ -d "$src_dir" ]] || fail "源目录不存在：$src_dir"
  mkdir -p "$dst_dir"

  local src_fullchain="$src_dir/fullchain.pem"
  local src_privkey="$src_dir/privkey.pem"

  [[ -f "$src_fullchain" ]] || fail "缺少文件：$src_fullchain"
  [[ -f "$src_privkey"   ]] || fail "缺少文件：$src_privkey"

  # 拷贝并设置合理权限
  install -m 0644 "$src_fullchain" "$dst_dir/fullchain.pem"
  install -m 0644 "$src_privkey"   "$dst_dir/privkey.pem"

  log "已复制证书：$src_fullchain -> $dst_dir/fullchain.pem"
  log "已复制私钥：$src_privkey   -> $dst_dir/privkey.pem"
}

nginx_test_and_reload() {
  # 先测试，再 reload
  if output="$("$NGINX_BIN" -t 2>&1)"; then
    log "nginx -t 成功：$output"
    "$NGINX_BIN" -s reload
    log "已执行：nginx -s reload"
  else
    log "nginx -t 失败：$output"
    fail "nginx 配置测试失败，已停止自动 reload。"
  fi
}

#####################################
# 部署钩子（仅在证书更新时被 certbot 调用）
#####################################

deploy_mode() {
  # certbot 在 --deploy-hook 中会设置如下环境变量
  # RENEWED_LINEAGE：此次续期证书的绝对路径（如 /etc/letsencrypt/live/example.com）
  : "${RENEWED_LINEAGE:?RENEWED_LINEAGE 未设置，非正常 deploy 环境}"

  local lineage_base
  lineage_base="$(basename "$RENEWED_LINEAGE")"

  log "检测到证书续签成功：$RENEWED_LINEAGE"

  local mapped
  mapped="$(find_map_value "$lineage_base")"
  if [[ -z "$mapped" ]]; then
    # 若未配置映射，则默认同名目录
    mapped="$lineage_base"
    log "未在映射表中找到 $lineage_base，使用同名目标目录：$mapped"
  else
    log "映射：$lineage_base -> $mapped"
  fi

  copy_cert "$lineage_base" "$mapped"
  nginx_test_and_reload

  log "部署钩子处理完成：$lineage_base"
}

#####################################
# 主流程
#####################################

main_mode() {
  ensure_root

  [[ -n "$CERT_PATH" ]] || fail "CERT_PATH 不能为空。当前 CERT_PATH='$CERT_PATH'"

  log "==== 开始执行 certbot 自动续签流程 ===="
  log "LIVE_PATH=$LIVE_PATH ; CERT_PATH=$CERT_PATH"

  # 使用自身作为 deploy-hook，只有当证书真正续签时才会调用 deploy_mode
  # 说明：使用 -q 可减少噪声，如需详细输出可去掉 -q
  local self
  self="$(readlink -f "$0" 2>/dev/null || realpath "$0")"

  # 将 certbot 输出也并入日志
  if output="$(certbot renew --deploy-hook "$self --deploy" 2>&1)"; then
    log "certbot renew 完成。输出："
    # 缩进打印
    while IFS= read -r line; do log "  $line"; done <<<"$output"
  else
    log "certbot renew 失败。输出："
    while IFS= read -r line; do log "  $line"; done <<<"$output"
    fail "certbot renew 执行失败。"
  fi

  log "==== 全部流程结束 ===="
}

#####################################
# 手动测试模式
#####################################

test_mode() {
  ensure_root
  local target="${1:-ALL}"

  log "==== 手动测试模式启动 ===="

  # 判断是单个域名还是全部
  if [[ "$target" == "ALL" ]]; then
    log "未指定域名，将测试全部映射（共 ${#keys[@]} 个）"
    # 如果数组为空则退出
    if [[ ${#keys[@]} -eq 0 ]]; then
      fail "keys 数组为空，请在脚本中定义至少一个域名。"
    fi
    for ((i=0; i<${#keys[@]}; i++)); do
      local domain="${keys[$i]}"
      local mapped
      mapped="$(find_map_value "$domain")"
      if [[ -z "$mapped" ]]; then
        mapped="$domain"
        log "未在映射表中找到 $domain，使用同名目录：$mapped"
      else
        log "映射：$domain -> $mapped"
      fi

      copy_cert "$domain" "$mapped"
    done
  else
    log "仅测试指定域名：$target"
    local mapped
    mapped="$(find_map_value "$target")"
    if [[ -z "$mapped" ]]; then
      mapped="$target"
      log "未在映射表中找到 $target，使用同名目录：$mapped"
    else
      log "映射：$target -> $mapped"
    fi
    copy_cert "$target" "$mapped"
  fi

  nginx_test_and_reload
  log "==== 手动测试模式结束（${target}） ===="
}

#####################################
# 入口
#####################################

case "${1:-}" in
  --deploy)
    # 作为 certbot 的 deploy-hook 被调用
    deploy_mode
    ;;
  --test)
    # 手动测试模式
    test_mode "${2:-}"
    ;;
  *)
    # 正常手动/定时任务入口
    main_mode
    ;;
esac
