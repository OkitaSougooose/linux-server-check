#!/bin/bash
# 强制设置字符编码，避免中文乱码
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
# ===================== 【基础路径配置（带默认值兜底）】 =====================
# 获取脚本绝对路径（兼容软链接）
BASE_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
# 定义核心目录，不存在则自动创建（增加容错）
REPORT_DIR="${BASE_DIR}/report"
LOG_DIR="${BASE_DIR}/logs"
TMP_DIR="${BASE_DIR}/tmp"
# 兜底机制：若目录创建失败，使用系统临时目录
mkdir -p "${REPORT_DIR}" "${LOG_DIR}" "${TMP_DIR}" || {
    REPORT_DIR="/tmp/linux_inspect/report"
    LOG_DIR="/tmp/linux_inspect/logs"
    TMP_DIR="/tmp/linux_inspect/tmp"
    mkdir -p "${REPORT_DIR}" "${LOG_DIR}" "${TMP_DIR}"
}
# ===================== 【发行版适配配置（修复树莓派识别）】 =====================
# 识别系统发行版（优先识别树莓派）
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="${NAME}"
    OS_ID="${ID}"
    OS_VERSION="${VERSION_ID}"
else
    OS_NAME="Unknown"
    OS_ID="unknown"
    OS_VERSION="unknown"
fi
# 适配不同发行版（新增raspbian分支，树莓派使用apt+ufw）
case "${OS_ID}" in
    raspbian|debian|ubuntu)
        export SYS_LOG="/var/log/syslog"
        export AUTH_LOG="/var/log/auth.log"
        export PKG_CMD="apt"
        export FIREWALL_CMD="ufw"
        export FIREWALL_STATUS_CMD="ufw status"
        ;;
    centos|rhel|fedora)
        export SYS_LOG="/var/log/messages"
        export AUTH_LOG="/var/log/secure"
        export PKG_CMD="yum"
        export FIREWALL_CMD="firewalld"
        export FIREWALL_STATUS_CMD="systemctl status firewalld"
        ;;
    *)
        export SYS_LOG="/var/log/syslog"
        export AUTH_LOG="/var/log/auth.log"
        export PKG_CMD="unknown"
        export FIREWALL_CMD="unknown"
        export FIREWALL_STATUS_CMD="echo '防火墙命令未知'"
        ;;
esac
# ===================== 【固定日志路径配置】 =====================
export KERNEL_LOG="/var/log/dmesg"
export KERN_LOG="/var/log/kern.log"
export NGINX_LOG="/var/log/nginx/access.log"
export NGINX_ERR_LOG="/var/log/nginx/error.log"
# ===================== 【采集/报告配置（统一时间戳）】 =====================
# 关键修复：时间戳仅首次生成，避免多次source导致文件名不一致
if [ -z "${CHECK_TIME}" ]; then
    CHECK_TIME=$(date +%Y-%m-%d_%H-%M-%S)
fi
# 报告/日志文件命名（增加发行版标识，方便归档）
export REPORT_FILE="${REPORT_DIR}/report_${OS_ID}_${CHECK_TIME}.txt"
export ERROR_LOG="${LOG_DIR}/error_${CHECK_TIME}.log"
export WARN_LOG="${LOG_DIR}/warn_${CHECK_TIME}.log"
export ANALYZE_LOG="${LOG_DIR}/analyze_${CHECK_TIME}.log"
# 结构化采集数据文件（供其他模块调用）
export COLLECT_DATA_FILE="${TMP_DIR}/collect_data_${CHECK_TIME}.json"
# ===================== 【阈值配置（可自定义，增加注释）】 =====================
export SHOW_LOG_COUNT=20                # 日志展示条数
export SHOW_PROCESS_COUNT=10            # 进程展示条数
export HISTORY_DAYS=7                   # 日志/报告保留天数
export CPU_THRESHOLD=80                 # CPU使用率告警阈值（%）
export MEM_THRESHOLD=85                 # 内存使用率告警阈值（%）
export DISK_THRESHOLD=85                # 磁盘使用率告警阈值（%）
export INODE_THRESHOLD=85               # Inode使用率告警阈值（%）
export LOAD_THRESHOLD=5.0               # 系统负载告警阈值
export ZOMBIE_PROC_THRESHOLD=5          # 僵尸进程告警阈值（个）
# ===================== 【关键词配置】 =====================
export ERROR_KEYWORDS="error|fail|panic|fatal|critical|alert|emerg|invalid|failed|error"
export WARN_KEYWORDS="warn|warning|notice|deprecated|slow|timeout"
export IMPORTANT_SERVICES="ssh cron rsyslog network-manager nginx mysql redis docker"
export NETWORK_PORTS="22 80 443 3306 6379 8080"
export CRITICAL_USERS="root ubuntu pi www-data mysql redis"
# ===================== 【采集项开关（灵活控制采集范围）】 =====================
export COLLECT_SELINUX=true    # 是否采集SELinux状态
export COLLECT_FIREWALL=true   # 是否采集防火墙状态
export COLLECT_UPDATE=true     # 是否采集系统更新包
export COLLECT_ZOMBIE=true     # 是否采集僵尸进程
export COLLECT_NET_CONN=true   # 是否采集网络连接数
# ===================== 【清理历史文件（增加日志轮转）】 =====================
# 按大小+时间清理：保留7天，且单个日志不超过100M
find "${REPORT_DIR}" -name "report_*.txt" -mtime +${HISTORY_DAYS} -delete 2>/dev/null
find "${LOG_DIR}" -name "*.log" -mtime +${HISTORY_DAYS} -delete 2>/dev/null
find "${LOG_DIR}" -name "*.log" -size +100M -delete 2>/dev/null
find "${TMP_DIR}" -name "*" -mtime +1 -delete 2>/dev/null
export SCRIPT_PATH="${BASH_SOURCE[0]}"