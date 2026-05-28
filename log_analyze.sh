#!/bin/bash
source ./config.sh
source ./utils.sh

# ===================== 核心修复1：非终端输出自动关闭颜色 =====================
if [ ! -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# ===================== 核心修复2：所有输出同时写入分析日志和终端 =====================
# 自动创建日志文件（防止目录不存在）
mkdir -p "$(dirname "$ANALYZE_LOG")" "$(dirname "$ERROR_LOG")" "$(dirname "$WARN_LOG")"
# 所有标准输出和错误输出同时写入分析日志文件和终端
exec > >(tee -a "$ANALYZE_LOG") 2>&1

# ===================== 日志分析主逻辑 =====================
echo ""
echo "================================================================"
echo "                     系 统 日 志 分 析 模 块"
echo "================================================================"
echo ""

# ===================== 1. 系统错误日志（完整写入ERROR_LOG） =====================
{
    echo "【 1. 系 统 错 误 日 志 】"
    echo "采集时间：$(date '+%Y-%m-%d %H:%M:%S')"
    echo "日志来源：$SYS_LOG"
    echo "----------------------------------------"

    if [ -f "$SYS_LOG" ]; then
        errors=$(grep -iE "$ERROR_KEYWORDS" "$SYS_LOG" 2>/dev/null | tail -n "$SHOW_LOG_COUNT")
        if [ -n "$errors" ]; then
            echo "$errors"
        else
            echo "✅ 未发现系统错误日志"
        fi
    else
        echo "❌ 系统日志文件不存在：$SYS_LOG"
    fi
} > "$ERROR_LOG"  # 完整写入错误日志文件
# 同时输出到终端和分析日志
cat "$ERROR_LOG"

echo ""
echo ""

# ===================== 2. 系统警告日志（完整写入WARN_LOG） =====================
{
    echo "【 2. 系 统 警 告 日 志 】"
    echo "采集时间：$(date '+%Y-%m-%d %H:%M:%S')"
    echo "日志来源：$SYS_LOG"
    echo "----------------------------------------"

    if [ -f "$SYS_LOG" ]; then
        warns=$(grep -iE "$WARN_KEYWORDS" "$SYS_LOG" 2>/dev/null | tail -n "$SHOW_LOG_COUNT")
        if [ -n "$warns" ]; then
            echo "$warns"
        else
            echo "✅ 未发现系统警告日志"
        fi
    else
        echo "❌ 系统日志文件不存在：$SYS_LOG"
    fi
} > "$WARN_LOG"  # 完整写入警告日志文件
# 同时输出到终端和分析日志
cat "$WARN_LOG"

echo ""
echo ""

# ===================== 3. 认证安全日志（写入ANALYZE_LOG） =====================
echo "【 3. 认 证 安 全 日 志 】"
echo "日志来源：$AUTH_LOG"
echo "----------------------------------------"
if [ -f "$AUTH_LOG" ]; then
    auth_errors=$(grep -iE "fail|error|invalid|warning" "$AUTH_LOG" 2>/dev/null | tail -n 15)
    if [ -n "$auth_errors" ]; then
        echo "$auth_errors"
    else
        echo "✅ 未发现认证安全异常"
    fi
else
    echo "❌ 认证日志文件不存在：$AUTH_LOG"
fi

echo ""
echo ""

# ===================== 4. 内核日志（写入ANALYZE_LOG） =====================
echo "【 4. 内 核 日 志 】"
echo "----------------------------------------"
if command -v dmesg &>/dev/null; then
    kernel_errors=$(dmesg | grep -iE "error|warn|fail" | grep -v "lvm2-activation-generator" 2>/dev/null | tail -n 15)
    if [ -n "$kernel_errors" ]; then
        echo "$kernel_errors"
    else
        echo "✅ 未发现内核异常"
    fi
else
    echo "❌ 系统不支持dmesg命令"
fi

echo ""
echo ""

# ===================== 5. 关键服务状态（写入ANALYZE_LOG） =====================
echo "【 5. 关 键 服 务 状 态 】"
echo "----------------------------------------"
for s in $IMPORTANT_SERVICES; do
    check_service "$s"
done

echo ""
echo ""

# ===================== 6. 端口监测（写入ANALYZE_LOG） =====================
echo "【 6. 端 口 监 测 】"
echo "监测端口：$NETWORK_PORTS"
echo "----------------------------------------"
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
echo ""

# ===================== 7. 磁盘空间检查（写入ANALYZE_LOG） =====================
echo "【 7. 磁 盘 空 间 检 查 】"
echo "----------------------------------------"
check_disk

echo ""
echo ""

# ===================== 8. 日志统计（追加到对应日志文件） =====================
echo "【 8. 日 志 统 计 】"
echo "----------------------------------------"
err_total=0
warn_total=0
if [ -f "$SYS_LOG" ]; then
    err_total=$(grep -iE "$ERROR_KEYWORDS" "$SYS_LOG" 2>/dev/null | grep -c .)
    warn_total=$(grep -iE "$WARN_KEYWORDS" "$SYS_LOG" 2>/dev/null | grep -c .)
fi
echo "错误日志总数：$err_total"
echo "警告日志总数：$warn_total"

# 把统计信息追加到错误和警告日志文件
echo "" >> "$ERROR_LOG"
echo "统计信息：" >> "$ERROR_LOG"
echo "错误日志总数：$err_total" >> "$ERROR_LOG"

echo "" >> "$WARN_LOG"
echo "统计信息：" >> "$WARN_LOG"
echo "警告日志总数：$warn_total" >> "$WARN_LOG"

echo ""
echo "================================================================"
echo "                     日 志 分 析 完 成"
echo "================================================================"
echo ""
echo "📄 错误日志文件：$ERROR_LOG"
echo "📄 警告日志文件：$WARN_LOG"
echo "📄 完整分析日志：$ANALYZE_LOG"