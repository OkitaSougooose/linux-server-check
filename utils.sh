#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO] $(date '+%Y-%m-%d %H:%M:%S') $* ${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN] $(date '+%Y-%m-%d %H:%M:%S') $* ${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $* ${NC}"
}

ok() {
    echo -e "${GREEN}[OK] $*${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN] $*${NC}"
}

fail() {
    echo -e "${RED}[FAIL] $*${NC}"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_warn "当前非 root 权限，部分信息无法读取"
    fi
}

check_service() {
    if command -v systemctl &>/dev/null; then
        if systemctl is-active --quiet "$1" 2>/dev/null; then
            ok "$1 服务运行正常"
        else
            warn "$1 服务未运行"
        fi
    else
        warn "$1 服务检查不可用"
    fi
}

check_disk() {
    if command -v df &>/dev/null; then
        df -h | grep -vE 'tmpfs|loop' | while read -r line; do
            use=$(echo "$line" | awk '{print $5}' | tr -d '%')
            if [[ "$use" =~ ^[0-9]+$ ]]; then
                if [ "$use" -ge 85 ]; then
                    fail "磁盘使用率过高：$line"
                else
                    ok "磁盘正常：$line"
                fi
            fi
        done
    fi
}