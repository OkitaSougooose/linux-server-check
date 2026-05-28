#!/bin/bash
source ./config.sh
source ./utils.sh

echo ""
echo "================================================================"
echo "                     系 统 日 志 分 析 模 块"
echo "================================================================"
echo ""

echo "【 1. 系 统 错 误 日 志 】"
if [ -f "$SYS_LOG" ]; then
    grep -iE "$ERROR_KEYWORDS" "$SYS_LOG" 2>/dev/null | tail -n "$SHOW_LOG_COUNT" | tee -a "$ERROR_LOG"
else
    echo "无系统日志"
fi
echo ""

echo "【 2. 系 统 警 告 日 志 】"
if [ -f "$SYS_LOG" ]; then
    grep -iE "$WARN_KEYWORDS" "$SYS_LOG" 2>/dev/null | tail -n "$SHOW_LOG_COUNT" | tee -a "$WARN_LOG"
else
    echo "无系统日志"
fi
echo ""

echo "【 3. 认 证 安 全 日 志 】"
if [ -f "$AUTH_LOG" ]; then
    grep -iE "fail|error|invalid|warning" "$AUTH_LOG" 2>/dev/null | tail -n 15
else
    echo "无认证日志"
fi
echo ""

echo "【 4. 内 核 日 志 】"
if command -v dmesg &>/dev/null; then
    dmesg | grep -iE "error|warn|fail" | grep -v "lvm2-activation-generator" 2>/dev/null | tail -n 15
else
    echo "无内核日志"
fi
echo ""

echo "【 5. 关 键 服 务 状 态 】"
for s in $IMPORTANT_SERVICES; do
    check_service "$s"
done
echo ""

echo "【 6. 端 口 监 测 】"
for p in $NETWORK_PORTS; do
    if command -v ss &>/dev/null; then
        if ss -tuln | grep ":$p" &>/dev/null; then
            ok "端口 $p 已监听"
        else
            warn "端口 $p 未监听"
        fi
    fi
done
echo ""

echo "【 7. 磁 盘 空 间 检 查 】"
check_disk
echo ""

echo "【 8. 日 志 统 计 】"
err_total=0
warn_total=0
if [ -f "$SYS_LOG" ]; then
    err_total=$(grep -iE "$ERROR_KEYWORDS" "$SYS_LOG" 2>/dev/null | grep -c .)
    warn_total=$(grep -iE "$WARN_KEYWORDS" "$SYS_LOG" 2>/dev/null | grep -c .)
fi
echo "错误日志总数：$err_total"
echo "警告日志总数：$warn_total"
echo ""

echo "================================================================"
echo "                     日 志 分 析 完 成"
echo "================================================================"