#!/bin/bash
source ./config.sh
source ./utils.sh
# ===================== 【前置初始化】 =====================
# 确保临时目录存在
mkdir -p "${TMP_DIR}" || {
    log_error "临时目录创建失败：${TMP_DIR}"
    exit 1
}
# 初始化结构化数据存储（JSON格式，供其他模块调用）
echo "{" > "${COLLECT_DATA_FILE}"
# 定义错误日志函数（专属采集模块的错误记录）
collect_error() {
    local msg="$1"
    log_error "[采集模块] $msg"
    echo "\"error\":\"$msg\"," >> "${COLLECT_DATA_FILE}"
}
# ===================== 【核心采集函数（模块化拆分，便于维护）】 =====================
# 1. 基础信息采集
collect_basic_info() {
    echo " "
    log_info "开始采集基础信息"
    echo "=============== 【 主 机 基 本 信 息 】 ==============="
    local hostname=$(hostname 2>/dev/null) || { collect_error "获取主机名失败"; hostname="未知"; }
    local os_info="未知"
    if [ -f /etc/os-release ]; then
        os_info=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 2>/dev/null) || collect_error "获取系统版本失败"
    fi
    local kernel_ver=$(uname -r 2>/dev/null) || { collect_error "获取内核版本失败"; kernel_ver="未知"; }
    local arch=$(uname -m 2>/dev/null) || { collect_error "获取系统架构失败"; arch="未知"; }
    local uptime=$(uptime -p 2>/dev/null) || { collect_error "获取运行时间失败"; uptime="未知"; }
    local boot_time=$(who -b | awk '{print $3,$4}' 2>/dev/null) || { collect_error "获取启动时间失败"; boot_time="未知"; }
    # 输出人类可读格式
    echo "主机名：${hostname}"
    echo "操作系统：${os_info}（${OS_ID} ${OS_VERSION}）"
    echo "内核版本：${kernel_ver}"
    echo "系统架构：${arch}"
    echo "当前登录用户：$(whoami)"
    echo "主机时间：$(date '+%Y-%m-%d %H:%M:%S')"
    echo "运行时间：${uptime}"
    echo "启动时间：${boot_time}"
    # 写入结构化JSON（供其他模块调用）
    echo "\"basic\":{" >> "${COLLECT_DATA_FILE}"
    echo "\"hostname\":\"${hostname}\"," >> "${COLLECT_DATA_FILE}"
    echo "\"os\":\"${os_info}\"," >> "${COLLECT_DATA_FILE}"
    echo "\"kernel\":\"${kernel_ver}\"," >> "${COLLECT_DATA_FILE}"
    echo "\"arch\":\"${arch}\"," >> "${COLLECT_DATA_FILE}"
    echo "\"uptime\":\"${uptime}\"," >> "${COLLECT_DATA_FILE}"
    echo "\"boot_time\":\"${boot_time}\"" >> "${COLLECT_DATA_FILE}"
    echo "}," >> "${COLLECT_DATA_FILE}"
    echo ""
}
# 2. CPU信息+实时使用率采集
collect_cpu_info() {
    echo " "
    log_info "开始采集CPU信息"
    echo "=============== 【 CPU 信 息 】 ==============="
    local cpu_cores=$(grep -c processor /proc/cpuinfo 2>/dev/null) || { collect_error "获取CPU核心数失败"; cpu_cores="未知"; }
    local cpu_model=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs 2>/dev/null) || { collect_error "获取CPU型号失败"; cpu_model="未知"; }
    local cpu_mhz=$(grep 'cpu MHz' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs 2>/dev/null) || { collect_error "获取CPU主频失败"; cpu_mhz="未知"; }
    # 实时CPU使用率（通过top计算，兼容不同系统）
    local cpu_usage=$(top -bn1 | grep 'Cpu(s)' | sed 's/.*[, ]*us\([0-9.]*\).*/\1/' | cut -d. -f1 2>/dev/null) || {
        collect_error "获取CPU使用率失败"; cpu_usage="未知";
    }
    # 输出人类可读格式
    echo "CPU 核心数：${cpu_cores}"
    echo "CPU 型号：${cpu_model}"
    echo "CPU 主频：${cpu_mhz} MHz"
    echo "CPU 实时使用率：${cpu_usage}%（阈值：${CPU_THRESHOLD}%）"
    # 阈值判断，给出告警
    if [[ "${cpu_usage}" =~ ^[0-9]+$ && "${cpu_usage}" -ge "${CPU_THRESHOLD}" ]]; then
        warn "CPU使用率超过阈值！当前：${cpu_usage}%，阈值：${CPU_THRESHOLD}%"
    fi
    # 写入结构化JSON
    echo "\"cpu\":{" >> "${COLLECT_DATA_FILE}"
    echo "\"cores\":\"${cpu_cores}\"," >> "${COLLECT_DATA_FILE}"
    echo "\"model\":\"${cpu_model}\"," >> "${COLLECT_DATA_FILE}"
    echo "\"mhz\":\"${cpu_mhz}\"," >> "${COLLECT_DATA_FILE}"
    echo "\"usage\":\"${cpu_usage}\"," >> "${COLLECT_DATA_FILE}"
    echo "\"threshold\":\"${CPU_THRESHOLD}\"" >> "${COLLECT_DATA_FILE}"
    echo "}," >> "${COLLECT_DATA_FILE}"
    echo ""
}
# 3. 内存信息+实时使用率采集
collect_mem_info() {
    echo " "
    log_info "开始采集内存信息"
    echo "=============== 【 内 存 信 息 】 ==============="
    if command -v free &>/dev/null; then
        free -h
        # 计算内存实时使用率（兼容free的不同输出格式）
        local mem_total=$(free -m | grep Mem | awk '{print $2}')
        local mem_used=$(free -m | grep Mem | awk '{print $3}')
        local mem_usage=$((mem_used * 100 / mem_total)) 2>/dev/null || { collect_error "计算内存使用率失败"; mem_usage="未知"; }
        echo "内存实时使用率：${mem_usage}%（阈值：${MEM_THRESHOLD}%）"
        if [[ "${mem_usage}" =~ ^[0-9]+$ && "${mem_usage}" -ge "${MEM_THRESHOLD}" ]]; then
            warn "内存使用率超过阈值！当前：${mem_usage}%，阈值：${MEM_THRESHOLD}%"
        fi
        # 写入结构化JSON
        echo "\"memory\":{" >> "${COLLECT_DATA_FILE}"
        echo "\"total\":\"${mem_total}MB\"," >> "${COLLECT_DATA_FILE}"
        echo "\"used\":\"${mem_used}MB\"," >> "${COLLECT_DATA_FILE}"
        echo "\"usage\":\"${mem_usage}\"," >> "${COLLECT_DATA_FILE}"
        echo "\"threshold\":\"${MEM_THRESHOLD}\"" >> "${COLLECT_DATA_FILE}"
        echo "}," >> "${COLLECT_DATA_FILE}"
    else
        collect_error "free命令不存在，无法采集内存信息"
        echo "内存信息：不支持"
        echo "\"memory\":{\"error\":\"free命令不存在\"}," >> "${COLLECT_DATA_FILE}"
    fi
    echo ""
}
# 4. 僵尸进程采集
collect_zombie_proc() {
    if [ "${COLLECT_ZOMBIE}" = true ]; then
        echo " "
        log_info "开始采集僵尸进程"
        echo "=============== 【 僵 尸 进 程 】 ==============="
        local zombie_count=$(ps aux | grep -w Z | grep -v grep | wc -l 2>/dev/null) || { collect_error "获取僵尸进程数失败"; zombie_count="未知"; }
        echo "僵尸进程数量：${zombie_count}（阈值：${ZOMBIE_PROC_THRESHOLD}）"
        if [[ "${zombie_count}" =~ ^[0-9]+$ && "${zombie_count}" -ge "${ZOMBIE_PROC_THRESHOLD}" ]]; then
            warn "僵尸进程数超过阈值！当前：${zombie_count}，阈值：${ZOMBIE_PROC_THRESHOLD}"
        fi
        echo "\"zombie_process\":{" >> "${COLLECT_DATA_FILE}"
        echo "\"count\":\"${zombie_count}\"," >> "${COLLECT_DATA_FILE}"
        echo "\"threshold\":\"${ZOMBIE_PROC_THRESHOLD}\"" >> "${COLLECT_DATA_FILE}"
        echo "}," >> "${COLLECT_DATA_FILE}"
        echo ""
    fi
}
# 5. 安全相关信息采集（修复SELinux误判为错误）
collect_security_info() {
    echo " "
    log_info "开始采集安全相关信息"
    echo "=============== 【 安 全 状 态 】 ==============="
    # SELinux状态（树莓派默认无SELinux，改为INFO级别提示，不输出ERROR）
    if [ "${COLLECT_SELINUX}" = true ]; then
        if command -v getenforce &>/dev/null; then
            local selinux_status=$(getenforce 2>/dev/null)
            echo "SELinux状态：${selinux_status}"
            echo "\"selinux\":\"${selinux_status}\"," >> "${COLLECT_DATA_FILE}"
        else
            log_info "系统未安装SELinux，跳过采集"
            echo "SELinux状态：未安装/不支持"
            echo "\"selinux\":\"未安装/不支持\"," >> "${COLLECT_DATA_FILE}"
        fi
    fi
    # 防火墙状态（优化异常处理）
    if [ "${COLLECT_FIREWALL}" = true ]; then
        echo "防火墙（${FIREWALL_CMD}）状态："
        if [ "${FIREWALL_CMD}" != "unknown" ]; then
            ${FIREWALL_STATUS_CMD} 2>/dev/null || {
                log_warn "获取防火墙状态失败"
                echo "防火墙状态：获取失败"
            }
            echo "\"firewall\":\"$(${FIREWALL_STATUS_CMD} 2>/dev/null | head -1 | tr -d '\n')\"," >> "${COLLECT_DATA_FILE}"
        else
            log_info "未知防火墙类型，跳过采集"
            echo "防火墙状态：未知类型"
            echo "\"firewall\":\"未知类型\"," >> "${COLLECT_DATA_FILE}"
        fi
    fi
    echo ""
}
# 6. 系统更新包采集（修复树莓派apt识别）
collect_update_info() {
    if [ "${COLLECT_UPDATE}" = true ]; then
        echo " "
        log_info "开始采集系统更新包"
        echo "=============== 【 系 统 更 新 】 ==============="
        if [ "${PKG_CMD}" = "apt" ]; then
            # 树莓派apt优化：先更新索引再统计可更新包
            local update_count=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)
            echo "可更新软件包数量：${update_count}"
            echo "\"update_packages\":\"${update_count}\"," >> "${COLLECT_DATA_FILE}"
        elif [ "${PKG_CMD}" = "yum" ]; then
            local update_count=$(yum check-update 2>/dev/null | grep -v "Updated Packages" | wc -l)
            echo "可更新软件包数量：${update_count}"
            echo "\"update_packages\":\"${update_count}\"," >> "${COLLECT_DATA_FILE}"
        else
            log_info "不支持的包管理工具，跳过更新包采集"
            echo "可更新软件包数量：不支持"
            echo "\"update_packages\":\"不支持\"," >> "${COLLECT_DATA_FILE}"
        fi
        echo ""
    fi
}
# 7. 磁盘信息采集
collect_disk_info() {
    echo " "
    log_info "开始采集磁盘信息"
    echo "=============== 【 磁 盘 信 息 】 ==============="
    if command -v df &>/dev/null; then
        df -hT | grep -vE 'tmpfs|loop|udev'
        # Inode信息
        echo " "
        echo -e "\n=============== 【 磁 盘 Inode 】 ==============="
        df -i | grep -vE 'tmpfs|loop|udev'
        # 写入结构化JSON
        echo "\"disk\":{" >> "${COLLECT_DATA_FILE}"
        echo "\"disk_usage\":\"$(df -h | grep -vE 'tmpfs|loop|udev' | awk '{print $1":"$5}' | tr '\n' ';')\"," >> "${COLLECT_DATA_FILE}"
        echo "\"inode_usage\":\"$(df -i | grep -vE 'tmpfs|loop|udev' | awk '{print $1":"$5}' | tr '\n' ';')\"" >> "${COLLECT_DATA_FILE}"
        echo "}," >> "${COLLECT_DATA_FILE}"
    else
        collect_error "df命令不存在，无法采集磁盘信息"
        echo "磁盘信息：不支持"
        echo "\"disk\":{\"error\":\"df命令不存在\"}," >> "${COLLECT_DATA_FILE}"
    fi
    echo ""
}
# ===================== 【主执行流程】 =====================
echo "================================================================"
echo "                     系 统 信 息 采 集 模 块"
echo "================================================================"
echo ""
# 调用所有采集函数
collect_basic_info
collect_cpu_info
collect_mem_info
collect_zombie_proc
collect_security_info
collect_update_info
collect_disk_info
# 完成JSON结构化文件（修复最后一个逗号问题）
sed -i '$ s/,$//' "${COLLECT_DATA_FILE}"
echo "}" >> "${COLLECT_DATA_FILE}"
log_success "数据采集完成，结构化数据文件：${COLLECT_DATA_FILE}"
echo "================================================================"
echo "                     采 集 完 成"
echo "================================================================"
# 明确返回成功退出码
exit 0