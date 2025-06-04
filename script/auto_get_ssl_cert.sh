#!/bin/bash

# 脚本作用: 自动申请 Let's Encrypt SSL 证书
# 适用于多个域名，支持 www 和非 www 域名
# 需要安装 Certbot，并且服务器上已配置好对应的 webroot 路径
# 仅支持 Let's Encrypt 的 webroot 方式申请证书

# 配置部分：为每个域名定义对应的 webroot
keys=("example.com" "sub.example.com")  # 域名列表
values=("/var/www/html" "/var/www/sub")  # 对应的 webroot 列表

EMAIL="your_email@example.com"  # 你的邮箱
CUSTOM_PATH=""  # 证书存放路径（留空则使用默认路径）

# 检查是否安装 Certbot
if ! command -v certbot &>/dev/null; then
    echo "Certbot 未安装，正在安装..."
    sudo apt update
    sudo apt install certbot -y
fi

# 判断是否需要使用 sudo
CERTBOT_CMD="certbot"
if [ "$(id -u)" -ne 0 ]; then
    CERTBOT_CMD="sudo certbot"
fi

# 申请证书的函数
request_certificate() {
    local domain="$1"
    local webroot="$2"

    # 处理 www 开头的域名
    if [[ "$domain" =~ ^www\.(.+)$ ]]; then
        base_domain="${BASH_REMATCH[1]}"
        echo "检测到域名 $domain 是 www 开头，将自动为 $base_domain 申请证书。"
        domains="-d $domain -d $base_domain"
    else
        domains="-d $domain"
    fi

    # 组装 Certbot 命令
    CERTBOT_OPTIONS="--webroot -w \"$webroot\" $domains -m \"$EMAIL\" --agree-tos --non-interactive --quiet"
    
    # 如果定义了 CUSTOM_PATH，则添加 --config-dir 选项
    if [[ -n "$CUSTOM_PATH" ]]; then
        CERTBOT_OPTIONS+=" --config-dir \"$CUSTOM_PATH\""
    fi

    echo "正在为域名 $domain 使用 webroot $webroot 申请证书..."
    
    # 执行 Certbot 申请证书
    eval "$CERTBOT_CMD certonly $CERTBOT_OPTIONS"

    # 检查申请是否成功
    if [ $? -eq 0 ]; then
        cert_path="${CUSTOM_PATH:-/etc/letsencrypt}/live/$domain"
        echo "✅ 证书申请成功！证书已存储到 $cert_path"
    else
        echo "❌ 证书申请失败！请检查域名 $domain 的配置或日志。"
    fi
}

# 遍历域名和对应的 webroot 申请证书
for i in "${!keys[@]}"; do
    domain="${keys[i]}"
    webroot="${values[i]}"

    # 检查 webroot 是否存在
    if [ ! -d "$webroot" ]; then
        echo "❌ 错误：webroot 目录 $webroot 不存在，跳过域名 $domain！"
        continue
    fi

    # 调用函数申请证书
    request_certificate "$domain" "$webroot"
done

echo "全部任务完成。"
