#!/bin/sh

set -e

echo "开始安装 hysteria2..."

# 安装基础依赖（尽量轻量）
apk add --no-cache wget curl openssl openrc >/dev/null 2>&1

# 生成随机密码
generate_random_password() {
  dd if=/dev/urandom bs=18 count=1 2>/dev/null | base64
}

GENPASS="$(generate_random_password)"

# 创建目录
mkdir -p /etc/hysteria

# 下载 hysteria
echo "下载 hysteria..."
wget -O /usr/local/bin/hysteria https://download.hysteria.network/app/latest/hysteria-linux-amd64 --no-check-certificate >/dev/null 2>&1
chmod +x /usr/local/bin/hysteria

# 生成证书（兼容 ash，不使用 bash 语法）
echo "生成自签名证书..."

openssl ecparam -name prime256v1 -genkey -noout -out /etc/hysteria/server.key
openssl req -new -x509 \
-key /etc/hysteria/server.key \
-out /etc/hysteria/server.crt \
-subj "/CN=bing.com" \
-days 36500 >/dev/null 2>&1

# 写配置文件
cat > /etc/hysteria/config.yaml << EOF
listen: :56125

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $GENPASS

masquerade:
  type: proxy
  proxy:
    url: https://bing.com/
    rewriteHost: true
EOF

# 写 OpenRC 服务
cat > /etc/init.d/hysteria << 'EOF'
#!/sbin/openrc-run

name="hysteria"
command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"
pidfile="/var/run/${name}.pid"
command_background="yes"

depend() {
    need networking
}
EOF

chmod +x /etc/init.d/hysteria
rc-update add hysteria >/dev/null 2>&1

# 启动服务
service hysteria restart >/dev/null 2>&1

echo "------------------------------------------------------------"
echo "hysteria2 安装完成"
echo ""
echo "端口: 56125 (UDP)"
echo "密码: $GENPASS"
echo "TLS: 开启"
echo "SNI: bing.com"
echo ""
echo "查看状态: service hysteria status"
echo "重启服务: service hysteria restart"
echo "配置文件: /etc/hysteria/config.yaml"
echo "------------------------------------------------------------"
