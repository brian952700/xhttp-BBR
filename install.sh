#!/usr/bin/env bash
# 一键安装入口：下载、检查并安装 xy，然后从终端启动交互菜单。
# 安装命令见 README.md；本文件不会重置已有 Xray 配置。

main() (
    set -euo pipefail
    umask 077
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    local base_url='https://raw.githubusercontent.com/brian952700/xhttp-BBR/main'
    local target=/usr/local/bin/xy tuning_dir=/usr/local/lib/xy temp script
    local cyan= reset=
    if [[ -t 1 && ! ${NO_COLOR+x} && ${TERM:-dumb} != dumb ]]; then
        cyan=$'\033[36m'; reset=$'\033[0m'
    fi
    printf '\n  %sXHTTP 管理脚本安装%s\n\n' "$cyan" "$reset"
    local -a elevate=()

    [[ $(uname -s) == Linux && -d /run/systemd/system ]] || {
        printf '错误：需要以 systemd 启动的 Linux 服务器。\n' >&2; exit 1;
    }
    # 通过管道运行时 stdin 是脚本数据，菜单必须单独连接到控制终端。
    if ! (exec 3<>/dev/tty) 2>/dev/null; then
        printf '错误：需要交互终端，请在 SSH 终端中运行安装命令。\n' >&2
        exit 1
    fi
    if (( EUID != 0 )); then
        command -v sudo >/dev/null || { printf '错误：请使用 root 运行，或先安装 sudo。\n' >&2; exit 1; }
        elevate=(sudo)
        sudo -v </dev/tty
    fi

    # 手动下载入口运行时也补齐下载器和 HTTPS 信任库。
    if ! command -v curl >/dev/null || [[ ! -s /etc/ssl/certs/ca-certificates.crt && ! -s /etc/pki/tls/certs/ca-bundle.crt ]]; then
        printf '\n  %s检查下载依赖：安装 curl、CA 证书…%s\n\n' "$cyan" "$reset"
        if command -v apt-get >/dev/null; then
            "${elevate[@]}" apt-get update
            "${elevate[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates
        elif command -v dnf >/dev/null || command -v yum >/dev/null; then
            local pm
            pm=$(command -v dnf || command -v yum)
            "${elevate[@]}" "$pm" install -y curl ca-certificates
        else
            printf '错误：无法自动安装依赖，不支持此包管理器。\n' >&2; exit 1
        fi
    fi

    temp=$(mktemp -d)
    trap 'rm -rf -- "$temp"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    printf '\n  %s正在下载 xy 管理脚本和网络调优脚本…%s\n\n' "$cyan" "$reset"
    for script in xy.sh enable-bbr.sh enable-tcp-autotune.sh; do
        curl --fail --show-error --location --proto '=https' --tlsv1.2 \
            --retry 3 --connect-timeout 20 --max-time 300 "$base_url/$script" -o "$temp/$script"
        [[ -s $temp/$script ]] || { printf '错误：下载的脚本为空：%s\n' "$script" >&2; exit 1; }
        bash -n "$temp/$script"
    done
    "${elevate[@]}" install -d -o root -g root -m 0755 "$tuning_dir"
    "${elevate[@]}" install -o root -g root -m 0755 \
        "$temp/enable-bbr.sh" "$temp/enable-tcp-autotune.sh" "$tuning_dir/"
    "${elevate[@]}" install -o root -g root -m 0755 "$temp/xy.sh" "$target"
    printf '\n  安装完成。以后使用 sudo xy（root 用户直接输入 xy）打开菜单。\n\n'
    "${elevate[@]}" "$target" </dev/tty
)

main "$@"
