#!/bin/bash
source ./config.sh
source ./utils.sh

CHECK_TIME=$(date "+%Y-%m-%d %H:%M:%S")
START_TIME=$(date +%s)  # 新增：计时开始

echo "开始生成巡检报告，请稍候..."

# 先初始化变量，消除“未赋值”警告
err_total=0
warn_total=0
if [ -f "$SYS_LOG" ]; then
    err_total=$(grep -iE "$ERROR_KEYWORDS" "$SYS_LOG" 2>/dev/null | grep -c .)
    warn_total=$(grep -iE "$WARN_KEYWORDS" "$SYS_LOG" 2>/dev/null | grep -c .)
fi

{
cat <<EOF
===============================================================
               Linux 系 统 全 面 巡 检 报 告
===============================================================
巡检时间：$CHECK_TIME
报告路径：$REPORT_FILE
系统用户：$(whoami)
===============================================================

【 1 】系统基础信息
EOF

./collect_info.sh

echo ""
echo "================================================================"
echo "【 2 】系统日志与安全分析"
echo "================================================================"
echo ""

./log_analyze.sh

echo ""
echo "================================================================"
echo "【 3 】巡检总结"
echo "================================================================"
echo ""

echo "巡检时间：$CHECK_TIME"
echo "错误日志总数：$err_total"
echo "警告日志总数：$warn_total"
echo "关键服务检查：已完成"
echo "磁盘状态检查：已完成"
echo "网络端口检查：已完成"

# ============= 新增巡检耗时、磁盘内存健康状态检测 =============
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
echo "巡检耗时：${ELAPSED_TIME} 秒"

# 新增磁盘健康状态
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$disk_usage" -ge 85 ]; then
    echo "磁盘健康状态：警告（使用率过高：${disk_usage}%）"
else
    echo "磁盘健康状态：正常（使用率：${disk_usage}%）"
fi

# 新增内存健康状态
mem_used=$(free | awk '/Mem/ {printf "%.0f", $3/$2*100}')
if [ "$mem_used" -ge 90 ]; then
    echo "内存健康状态：警告（使用率过高：${mem_used}%）"
else
    echo "内存健康状态：正常（使用率：${mem_used}%）"
fi
# ===================== 新增结束 =====================

echo ""
echo "================================================================"
echo "                     巡 检 结 束"
echo "================================================================"
} > "$REPORT_FILE"

echo "✅ 巡检报告已生成：$REPORT_FILE"