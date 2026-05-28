#!/bin/bash
source ./config.sh
source ./utils.sh

# ==============================================
# 【定时巡检开关控制】
# ==============================================
CRON_RULE="0 * * * *"

# 根据 CRON_RULE 自动生成友好显示文本
get_interval_text() {
    case "$CRON_RULE" in
        "*/1 * * * *") echo "每分钟自动执行" ;;
        "*/2 * * * *") echo "每2分钟自动执行" ;;
        "*/10 * * * *") echo "每10分钟自动执行" ;;
        "0 * * * *") echo "每小时自动执行" ;;
        "0 */2 * * *") echo "每2小时自动执行" ;;
        "30 */2 * * *") echo "每2小时30分钟自动执行" ;;
        *) echo "按自定义规则执行" ;;
    esac
}

# 获取当前脚本绝对路径
SCRIPT_PATH=$(realpath "$0")
CRON_COMMENT="# Linux课程项目巡检任务"

# ==============================================
# 定时任务操作函数
# ==============================================
check_crontab() {
    crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH auto"
    return $?
}

enable_crontab() {
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH auto"; echo "$CRON_RULE $SCRIPT_PATH auto $CRON_COMMENT") | crontab -
    echo -e "${GREEN}[√] 定时巡检已开启：$(get_interval_text)${NC}"
}

disable_crontab() {
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH auto") | crontab -
    echo -e "${RED}[×] 定时巡检已关闭${NC}"
}

# 按 天.小时.分 格式修改周期（新增输入-1返回菜单）
change_interval() {
    echo ""
    echo "请输入新的自动巡检周期（格式：天.小时.分，例如："
    echo "  0.0.1 → 每分钟一次"
    echo "  0.1.0 → 每小时一次"
    echo "  0.2.30 → 每2小时30分钟一次"
    echo "  1.0.0 → 每天一次（凌晨0点）"
    echo "输入格式：d.h.m（输入 -1 直接返回菜单）"
    read -p "请输入：" input

    # 输入-1，直接返回菜单
    if [ "$input" = "-1" ]; then
        echo -e "${YELLOW}[提示] 已取消修改，返回主菜单${NC}"
        return
    fi

    # 解析输入：天.小时.分
    IFS='.' read -r d h m <<< "$input"

    # 校验输入是否合法
    if [[ -z "$d" || -z "$h" || -z "$m" ]]; then
        echo -e "${RED}[×] 输入格式错误，请使用 天.小时.分 格式（例如 0.1.0）${NC}"
        return
    fi

    if (( d < 0 || d > 31 || h < 0 || h > 23 || m < 0 || m > 59 )); then
        echo -e "${RED}[×] 数值超出范围：天(0-31)、小时(0-23)、分(0-59)${NC}"
        return
    fi

    # 转换为crontab规则
    if (( d == 0 && h == 0 )); then
        # 每N分钟一次
        CRON_RULE="*/$m * * * *"
    elif (( d == 0 && m == 0 )); then
        # 每N小时一次
        CRON_RULE="0 */$h * * *"
    elif (( d == 0 && h > 0 && m > 0 )); then
        # 每N小时M分钟一次（如0.2.30 → 每2小时30分钟）
        CRON_RULE="$m */$h * * *"
    elif (( h == 0 && m == 0 )); then
        # 每天N点0分执行
        CRON_RULE="0 0 */$d * *"
    else
        # 固定时间执行（每天h点m分，每d天一次）
        CRON_RULE="$m $h */$d * *"
    fi

    echo -e "${GREEN}[√] 周期已更新为：$(get_interval_text)${NC}"
    echo -e "${YELLOW}提示：需重启定时巡检（菜单选项2）才能生效${NC}"
}

# 后台自动执行模式
if [ "$1" = "auto" ]; then
    cd "$(dirname "$SCRIPT_PATH")"
    ./report.sh
    exit 0
fi

# ==============================================
# 【主菜单】
# ==============================================
# 首次运行打印标题和状态
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}${GREEN}                     Linux 服务器巡检工具                     ${NC}${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 实时显示当前定时状态
if check_crontab; then
    echo -e "${YELLOW}当前状态：定时巡检已开启（$(get_interval_text)）${NC}"
else
    echo -e "${YELLOW}当前状态：定时巡检已关闭${NC}"
fi
echo ""

# 菜单循环，每次循环前加分隔线
while true; do
    # 分隔线，区分每次操作
    echo "--------------------------------------------------------"
    echo ""

    echo -e "${BLUE}请选择操作：${NC}"
    echo -e "  1) 立即执行一次全面巡检"
    echo -e "  2) 开启/关闭 自动定时巡检"
    echo -e "  3) 修改自动巡检周期（天.小时.分）"
    echo -e "  4) 查看巡检报告目录"
    echo -e "  5) 查看系统日志目录"
    echo -e "  6) 退出程序"
    echo ""

    read -p "请输入选项 [1-6]：" opt
    echo ""

    case $opt in
        1)
            log_info "开始执行全面巡检..."
            ./report.sh
            echo ""
            ;;
        2)
            if check_crontab; then
                disable_crontab
            else
                enable_crontab
            fi
            echo ""
            ;;
        3)
            change_interval
            echo ""
            ;;
        4)
            echo -e "${BLUE}===== 巡检报告目录（$REPORT_DIR） =====${NC}"
            ls -lh "$REPORT_DIR"
            echo ""
            ;;
        5)
            echo -e "${BLUE}===== 系统日志目录（$LOG_DIR） =====${NC}"
            ls -lh "$LOG_DIR"
            echo ""
            ;;
        6)
            echo -e "${GREEN}退出程序，再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}输入错误，请输入 1-6 之间的数字！${NC}"
            echo ""
            ;;
    esac
done
