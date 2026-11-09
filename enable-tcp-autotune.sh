#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ $(uname -s) != Linux || $EUID != 0 ]]; then
    printf '错误：请在 Linux 上以 root 身份运行。\n' >&2
    exit 1
fi

key=net.ipv4.tcp_moderate_rcvbuf
value=1
config=/etc/sysctl.d/99-xy-tcp-autotune.conf
previous=$(sysctl -n "$key")

install -d -m 0755 /etc/sysctl.d
temp=$(mktemp "${config}.XXXXXX")
trap 'rm -f -- "$temp"' EXIT
printf '%s = %s\n' "$key" "$value" >"$temp"
chmod 0644 "$temp"

sysctl -w "$key=$value" >/dev/null
if ! mv -fT -- "$temp" "$config"; then
    sysctl -w "$key=$previous" >/dev/null
    exit 1
fi
printf 'TCP 接收缓冲区自适应调优已开启（%s = %s）。配置已写入 %s。\n' "$key" "$value" "$config"
