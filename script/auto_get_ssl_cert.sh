#!/bin/bash

# 仅支持 Let's Encrypt 的 webroot 方式申请证书

# 配置部分：为每个域名定义对应的 webroot
keys=("example.com" "sub.example.com" "anotherdomain.com")  # 域名列表
values=("/var/www/html" "/var/www/sub" "/var/www/another")  # 对应的 webroot 列表

EMAIL="your_email@example.com"        # 你的邮箱
CUSTOM_PATH="/custom/path"            # 证书存放路径

# 检查是否安装 Certbot
if ! command -v certbot &>/dev/null; then
    echo "Certbot 未安装，正在安装..."
    sudo apt update
    sudo apt install certbot -y
fi

# 申请证书的函数
request_certificate() {
    local domain="$1"
    local webroot="$2"

    # 如果域名以 www 开头，提取不带 www 的域名
    if [[ "$domain" =~ ^www\.(.+)$ ]]; then
        base_domain="${BASH_REMATCH[1]}"
        echo "检测到域名 $domain 是 www 开头，将自动为 $base_domain 申请证书。"

        # 为 www 和不带 www 的域名一起申请证书
        sudo certbot certonly \
            --webroot -w "$webroot" \
            -d "$domain" -d "$base_domain" \
            -m "$EMAIL" \
            --config-dir "$CUSTOM_PATH" \
            --agree-tos \
            --non-interactive \
            --quiet
    else
        echo "正在为域名 $domain 使用 webroot $webroot 申请证书..."

        # 仅为单个域名申请证书
        sudo certbot certonly \
            --webroot -w "$webroot" \
            -d "$domain" \
            -m "$EMAIL" \
            --config-dir "$CUSTOM_PATH" \
            --agree-tos \
            --non-interactive \
            --quiet
    fi

    # 检查申请是否成功
    if [ $? -eq 0 ]; then
        echo "✅ 证书申请成功！证书已存储到 $CUSTOM_PATH/live/$domain"
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
