#!/bin/bash
# ==============================================
# 树莓派Linux系统自动巡检系统
# 新增：实时性能二级菜单 | 所有功能一键直达
# ==============================================
# 加载配置和工具函数
source ./config.sh
source ./utils.sh
# ===================== 颜色定义 =====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # 重置颜色
# ===================== 基础工具函数 =====================
# 清屏并显示标题（仅二级菜单调用）
show_header() {
    clear
    echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║                   █████╗ ██╗   ██╗████████╗ ██████╗               ║"
echo "║                  ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗              ║"
echo "║                  ███████║██║   ██║   ██║   ██║   ██║              ║"
echo "║                  ██╔══██║██║   ██║   ██║   ██║   ██║              ║"
echo "║                  ██║  ██║╚██████╔╝   ██║   ╚██████╔╝              ║" 
echo "║                  ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝               ║"
echo "║                                                                   ║"
echo "║                       Linux系统自动巡检系统                       ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 系统信息行（居中对齐）
    local sys_info="运行环境：$(uname -s) $(uname -r) | 主机名：$(hostname) | 当前时间：$(date '+%Y-%m-%d %H:%M:%S')"
    local path_info="报告目录：${REPORT_DIR} | 日志目录：${LOG_DIR}"
    
    printf "%*s\n" $(( (80 + ${#sys_info}) / 2 )) "$sys_info"
    printf "%*s\n" $(( (80 + ${#path_info}) / 2 )) "$path_info"
    
    echo "====================================================================="
    echo ""
}
# 显示加载动画
show_loading() {
    local msg="$1"
    local pid=$2
    local spin='-\|/'
    local i=0
    echo -n -e "${YELLOW}[加载中] ${msg}... ${NC}"
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        echo -n -e "\b${spin:$i:1}"
        sleep 0.1
    done
    echo -e "\b${GREEN}完成${NC}"
}
# 显示系统快速概览
show_system_overview() {
    echo -e "${BLUE}===== 系统实时状态概览 =====${NC}"
    local cpu_usage=$(top -bn1 | grep 'Cpu(s)' | sed 's/.*[, ]*us\([0-9.]*\).*/\1/' | cut -d. -f1 2>/dev/null || echo "未知")
    local mem_usage=$(free -m | grep Mem | awk '{printf "%.1f", $3/$2*100}' 2>/dev/null || echo "未知")
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | cut -d% -f1 2>/dev/null || echo "未知")
    local uptime=$(uptime -p 2>/dev/null || echo "未知")
    
    echo -e "CPU使用率：${cpu_usage}% | 内存使用率：${mem_usage}% | 磁盘使用率：${disk_usage}%"
    echo -e "系统运行时间：${uptime}"
    echo ""
}
# ===================== 实时性能二级菜单函数（保留清屏） =====================
# 1. 查看系统基础信息
show_basic_info() {
    echo -e "${GREEN}===== 系统基础信息 =====${NC}"
    echo "主机名：$(hostname)"
    echo "操作系统：$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 2>/dev/null)"
    echo "内核版本：$(uname -r)"
    echo "系统架构：$(uname -m)"
    echo "当前用户：$(whoami)"
    echo "启动时间：$(who -b | awk '{print $3,$4}' 2>/dev/null)"
    echo ""
}
# 2. 查看CPU实时状态
show_cpu_info() {
    echo -e "${GREEN}===== CPU实时状态 =====${NC}"
    echo "CPU型号：$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "CPU核心数：$(grep -c processor /proc/cpuinfo)"
    echo -e "实时使用率：\n$(top -bn1 | grep 'Cpu(s)')"
    echo ""
}
# 3. 查看内存使用详情
show_mem_info() {
    echo -e "${GREEN}===== 内存使用详情 =====${NC}"
    free -h
    echo ""
    echo "内存使用率：$(free -m | grep Mem | awk '{printf "%.1f%%", $3/$2*100}')"
    echo ""
}
# 4. 查看磁盘空间与Inode
show_disk_info() {
    echo -e "${GREEN}===== 磁盘空间使用 =====${NC}"
    df -hT | grep -vE 'tmpfs|loop|udev'
    echo ""
    echo -e "${GREEN}===== 磁盘Inode使用 =====${NC}"
    df -i | grep -vE 'tmpfs|loop|udev'
    echo ""
}
# 5. 查看网络连接状态
show_network_info() {
    echo -e "${GREEN}===== 网络接口信息 =====${NC}"
    ip addr show | grep -E 'inet|state UP' | grep -v '127.0.0.1'
    echo ""
    echo -e "${GREEN}===== 网络连接统计 =====${NC}"
    ss -tuln | head -10
    echo ""
}
# 6. 查看进程TOP排行
show_process_info() {
    echo -e "${GREEN}===== CPU占用TOP10进程 =====${NC}"
    ps aux --sort=-%cpu | head -11
    echo ""
    echo -e "${GREEN}===== 内存占用TOP10进程 =====${NC}"
    ps aux --sort=-%mem | head -11
    echo ""
}
# 7. 查看核心服务状态
show_service_info() {
    echo -e "${GREEN}===== 核心服务状态 =====${NC}"
    for service in ${IMPORTANT_SERVICES}; do
        if systemctl is-active --quiet "${service}"; then
            echo -e "${service}: ${GREEN}运行中${NC}"
        else
            echo -e "${service}: ${RED}已停止${NC}"
        fi
    done
    echo ""
}
# 8. 查看安全状态（防火墙/SELinux）
show_security_info() {
    echo -e "${GREEN}===== 安全状态 =====${NC}"
    if command -v getenforce &>/dev/null; then
        echo "SELinux状态：$(getenforce)"
    else
        echo "SELinux状态：未启用/不支持"
    fi
    echo ""
    echo "防火墙（${FIREWALL_CMD}）状态："
    ${FIREWALL_STATUS_CMD} 2>/dev/null | head -3
    echo ""
}
# 9. 查看僵尸进程
show_zombie_info() {
    echo -e "${GREEN}===== 僵尸进程信息 =====${NC}"
    local zombie_count=$(ps aux | grep -w Z | grep -v grep | wc -l)
    echo "僵尸进程数量：${zombie_count}"
    if [ "${zombie_count}" -gt 0 ]; then
        echo ""
        echo "僵尸进程列表："
        ps aux | grep -w Z | grep -v grep
    fi
    echo ""
}
# 性能二级菜单主入口（保留清屏）
performance_menu() {
    while true; do
        show_header
        echo -e "${BLUE}===== 快速查看系统性能 =====${NC}"
        echo ""
        echo -e "  ${WHITE}1.${NC} 系统基础信息"
        echo -e "  ${WHITE}2.${NC} CPU实时状态"
        echo -e "  ${WHITE}3.${NC} 内存使用详情"
        echo -e "  ${WHITE}4.${NC} 磁盘空间与Inode"
        echo -e "  ${WHITE}5.${NC} 网络连接状态"
        echo -e "  ${WHITE}6.${NC} 进程TOP排行（CPU/内存）"
        echo -e "  ${WHITE}7.${NC} 核心服务状态"
        echo -e "  ${WHITE}8.${NC} 安全状态（防火墙/SELinux）"
        echo -e "  ${WHITE}9.${NC} 僵尸进程信息"
        echo -e "  ${RED}0.${NC} 返回主菜单"
        echo ""
        read -p "请输入选项 [0-9]：" choice
        
        case $choice in
            1) show_basic_info ;;
            2) show_cpu_info ;;
            3) show_mem_info ;;
            4) show_disk_info ;;
            5) show_network_info ;;
            6) show_process_info ;;
            7) show_service_info ;;
            8) show_security_info ;;
            9) show_zombie_info ;;
            0) return ;;
            *) echo -e "${RED}❌ 无效选项，请重新输入${NC}"; sleep 1; continue ;;
        esac
        
        read -p "按回车键返回性能菜单："
    done
}
# ===================== 核心功能函数（全部去掉清屏） =====================
# 1. 一键全量巡检（去掉清屏+去掉查看报告）
full_inspection() {
    echo -e "${GREEN}===== 开始全量系统巡检 =====${NC}"
    echo ""
    
    (bash collect_info.sh > "${TMP_DIR}/collect.tmp" 2>&1) &
    show_loading "采集系统基础信息" $!
    
    (bash log_analyze.sh > "${TMP_DIR}/analyze.tmp" 2>&1) &
    show_loading "分析系统日志" $!
    
    (bash report.sh > "${TMP_DIR}/report.tmp" 2>&1) &
    show_loading "生成巡检报告" $!
    
    echo ""
    echo -e "${GREEN}✅ 全量巡检完成！${NC}"
    echo -e "📄 报告文件：${REPORT_FILE}"
    echo ""
    read -p "按回车键返回主菜单："
}
# 2. 单独运行数据采集（去掉清屏）
run_collect_only() {
    echo -e "${GREEN}===== 单独运行数据采集模块 =====${NC}"
    echo ""
    bash collect_info.sh
    echo ""
    echo -e "${GREEN}✅ 数据采集完成！${NC}"
    echo -e "📄 结构化数据文件：${COLLECT_DATA_FILE}"
    echo ""
    read -p "按回车键返回主菜单："
}
# 3. 单独运行日志分析（去掉清屏）
run_log_analyze_only() {
    echo -e "${GREEN}===== 单独运行日志分析模块 =====${NC}"
    echo ""
    bash log_analyze.sh
    echo ""
    echo -e "${GREEN}✅ 日志分析完成！${NC}"
    echo ""
    read -p "按回车键返回主菜单："
}
# 4. 查看历史报告（已修复无法返回问题）
view_history_reports() {
    echo -e "${BLUE}===== 历史巡检报告列表 =====${NC}"
    echo ""
    
    local reports=($(ls -t "${REPORT_DIR}"/report_*.txt 2>/dev/null))
    if [ ${#reports[@]} -eq 0 ]; then
        echo -e "${YELLOW}暂无历史报告${NC}"
        echo ""
        read -p "按回车键返回主菜单："
        return
    fi
    
    # 显示报告列表
    for i in "${!reports[@]}"; do
        local filename=$(basename "${reports[$i]}")
        local date=$(echo "$filename" | sed -E 's/report_.*_([0-9-]+)_([0-9-]+)\.txt/\1 \2/' | tr '_' ' ')
        echo -e "${WHITE}$((i+1)).${NC} ${filename} (${date})"
    done
    
    # 循环处理用户输入，直到输入有效
    while true; do
        echo ""
        read -p "请输入报告编号查看（输入0直接返回主菜单）：" num
        
        # 输入0：直接返回主菜单，无需额外按回车
        if [ "$num" = "0" ]; then
            return
        fi
        
        # 验证输入是否为有效数字
        if ! [[ "$num" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}❌ 请输入有效的数字编号${NC}"
            continue
        fi
        
        # 验证编号是否在范围内
        if [ "$num" -ge 1 ] && [ "$num" -le ${#reports[@]} ]; then
            # 查看报告，按q退出less后直接返回主菜单
            less "${reports[$((num-1))]}"
            return
        else
            echo -e "${RED}❌ 编号超出范围，请输入1-${#reports[@]}之间的数字${NC}"
        fi
    done
}
# 5. 配置定时任务（核心修复：解决/tmp权限问题）
setup_cron() {
    local CRON_MARKER="linux_inspect_auto_task"
    local current_dir=$(pwd)
    local cron_cmd="cd ${current_dir} && bash main.sh --auto # ${CRON_MARKER}"
    # 关键修复：将临时配置文件移到脚本自己的tmp目录，避免系统/tmp权限问题
    local cron_bak="${TMP_DIR}/cron_latest.conf"
    
    # 先删除旧的临时文件，避免残留
    rm -f "${cron_bak}" 2>/dev/null
    
    while true; do
        show_header
        echo -e "${BLUE}===== 定时巡检任务配置 =====${NC}"
        echo ""
        
        if crontab -l 2>/dev/null | grep -q "${CRON_MARKER}"; then
            echo -e "${GREEN}当前定时任务：已开启${NC}"
        else
            echo -e "${YELLOW}当前定时任务：未开启${NC}"
        fi
        
        echo ""
        echo "1. 配置：每天（点.分）自动巡检"
        echo "2. 配置：每隔（天.时.分）自动巡检"
        echo "3. 切换自动巡检 开/关"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项 [0-3]：" choice
        case $choice in
            1)
                echo -e "\n${YELLOW}请输入时间（格式：点.分，如18.35）：${NC}"
                read -p "输入：" time_str
                if [[ ! "$time_str" =~ ^[0-9]{1,2}\.[0-9]{1,2}$ ]]; then
                    echo -e "${RED}❌ 格式错误${NC}"
                    sleep 2
                    continue
                fi
                hour=$(echo "$time_str" | cut -d. -f1)
                minute=$(echo "$time_str" | cut -d. -f2)
                if [ "$hour" -lt 0 ] || [ "$hour" -gt 23 ] || [ "$minute" -lt 0 ] || [ "$minute" -gt 59 ]; then
                    echo -e "${RED}❌ 时间范围错误${NC}"
                    sleep 2
                    continue
                fi
                
                # 写入临时配置文件，增加错误处理
                echo "${minute} ${hour} * * * ${cron_cmd}" > "${cron_bak}" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ 已保存配置，可按3手动开启${NC}"
                else
                    echo -e "${RED}❌ 配置保存失败，请检查目录权限${NC}"
                fi
                ;;
            2)
                echo -e "\n${YELLOW}请输入间隔（格式：天.小时.分钟，如2.0.30）：${NC}"
                read -p "输入：" interval_str
                if [[ ! "$interval_str" =~ ^[0-9]+\.[0-9]{1,2}\.[0-9]{1,2}$ ]]; then
                    echo -e "${RED}❌ 格式错误${NC}"
                    sleep 2
                    continue
                fi
                days=$(echo "$interval_str" | cut -d. -f1)
                hours=$(echo "$interval_str" | cut -d. -f2)
                minutes=$(echo "$interval_str" | cut -d. -f3)
                local is_valid=1
                if [ "$days" -lt 0 ] || [ "$days" -gt 30 ]; then is_valid=0; fi
                if [ "$hours" -lt 0 ] || [ "$hours" -gt 23 ]; then is_valid=0; fi
                if [ "$minutes" -lt 1 ] || [ "$minutes" -gt 59 ]; then is_valid=0; fi
                if [ "${is_valid}" -eq 0 ]; then
                    echo -e "${RED}❌ 数值超出范围${NC}"
                    sleep 2
                    continue
                fi
                cron_minute="*/${minutes}"
                [ "$hours" -gt 0 ] && cron_hour="*/${hours}" || cron_hour="*"
                [ "$days" -gt 0 ] && cron_day="*/${days}" || cron_day="*"
                
                # 写入临时配置文件，增加错误处理
                echo "${cron_minute} ${cron_hour} * * ${cron_day} ${cron_cmd}" > "${cron_bak}" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ 已保存配置，可按3手动开启${NC}"
                else
                    echo -e "${RED}❌ 配置保存失败，请检查目录权限${NC}"
                fi
                ;;
            3)
                if crontab -l 2>/dev/null | grep -q "${CRON_MARKER}"; then
                    crontab -l | grep -v "${CRON_MARKER}" | crontab -
                    echo -e "${YELLOW}🔴 已关闭自动巡检${NC}"
                else
                    if [ -f "${cron_bak}" ] && [ -s "${cron_bak}" ]; then
                        local new_cron=$(cat "${cron_bak}")
                        crontab -l 2>/dev/null | grep -v "${CRON_MARKER}" | crontab -
                        echo "${new_cron}" | crontab -
                        echo -e "${GREEN}🟢 已启用保存的定时配置${NC}"
                    else
                        echo -e "${RED}❌ 暂无保存的定时配置，请先配置1或2${NC}"
                    fi
                fi
                ;;
            0)
                return ;;
            *)
                echo -e "${RED}❌ 无效选项${NC}"
                sleep 1
                ;;
        esac
        echo ""
        read -p "按回车键返回定时菜单："
    done
}
# 自动模式（用于定时任务）
auto_mode() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始自动巡检"
    bash collect_info.sh > /dev/null 2>&1
    bash log_analyze.sh > /dev/null 2>&1
    bash report.sh > /dev/null 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 自动巡检完成，报告：${REPORT_FILE}"
}
# ===================== 主菜单 =====================
main_menu() {
    while true; do
        show_header
        show_system_overview
        
        echo -e "${WHITE}请选择操作：${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 一键全量巡检"
        echo -e "  ${BLUE}2.${NC} 快速查看系统性能"
        echo -e "  ${CYAN}3.${NC} 单独运行数据采集模块"
        echo -e "  ${CYAN}4.${NC} 单独运行日志分析模块"
        echo -e "  ${YELLOW}5.${NC} 查看历史巡检报告"
        echo -e "  ${PURPLE}6.${NC} 配置定时巡检任务"
        echo -e "  ${RED}0.${NC} 退出系统"
        echo ""
        read -p "请输入选项 [0-6]：" choice
        
        case $choice in
            1) full_inspection ;;
            2) performance_menu ;;
            3) run_collect_only ;;
            4) run_log_analyze_only ;;
            5) view_history_reports ;;
            6) setup_cron ;;
            0)
                clear
                echo -e "${GREEN}感谢使用Linux系统自动巡检系统！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ 无效选项，请重新输入${NC}"
                sleep 1
                ;;
        esac
    done
}
# ===================== 程序入口 =====================
if [ "$1" = "--auto" ]; then
    auto_mode
else
    # 自动修复脚本权限
    if [ ! -x "./collect_info.sh" ] || [ ! -x "./log_analyze.sh" ] || [ ! -x "./report.sh" ]; then
        echo -e "${YELLOW}⚠️  检测到部分脚本缺少执行权限，正在自动修复...${NC}"
        chmod +x *.sh
        echo -e "${GREEN}✅ 权限修复完成${NC}"
        sleep 1
    fi
    
    main_menu
fi