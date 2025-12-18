#!/bin/bash
#
# Linux 服务器安装部署服务 - 主入口脚本
# 提供交互式菜单和命令行参数支持
#

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置和模块
source "$PROJECT_ROOT/config.sh"
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/package_matcher.sh"
source "$PROJECT_ROOT/lib/service_checker.sh"

# 版本信息
VERSION="1.0.0"

# 显示帮助信息
show_help() {
    cat << EOF
Linux 服务器安装部署服务 v${VERSION}

用法: $0 [选项]

选项:
    -n, --new           执行新部署安装
    -u, --upgrade       执行升级安装
    -s, --status        检查服务状态
    -l, --list          列出可用的安装包
    -h, --help          显示此帮助信息
    -v, --version       显示版本信息

示例:
    $0              # 交互式菜单
    $0 --new        # 直接执行新部署
    $0 --upgrade    # 直接执行升级
    $0 --status     # 检查所有服务状态

EOF
}

# 显示版本信息
show_version() {
    echo "Linux 服务器安装部署服务 v${VERSION}"
}

# 显示主菜单
show_menu() {
    clear
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${GREEN}Linux 服务器安装部署服务 v${VERSION}${NC}               ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}                                                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}1.${NC} 新部署安装                                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}2.${NC} 升级安装                                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}3.${NC} 检查服务状态                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}4.${NC} 查看可用安装包                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}5.${NC} 数据库内外网配置                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}6.${NC} 防火墙端口管理                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}7.${NC} 初始化目录结构                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}0.${NC} 退出                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 查看可用安装包
list_all_packages() {
    if [ -d "$DEPLOY_PACKAGES_DIR" ]; then
        list_deploy_packages "$DEPLOY_PACKAGES_DIR"
    else
        echo -e "  ${YELLOW}新部署目录不存在，请先初始化目录结构${NC}"
    fi
    
    if [ -d "$UPDATE_PACKAGES_DIR" ]; then
        list_upgrade_packages "$UPDATE_PACKAGES_DIR" "$DEPLOY_PACKAGES_DIR"
    else
        echo -e "  ${YELLOW}升级目录不存在，请先初始化目录结构${NC}"
    fi
}

# 执行新部署
do_deploy_new() {
    source "$PROJECT_ROOT/scripts/deploy_new.sh"
    run_deploy
}

# 执行升级
do_deploy_upgrade() {
    source "$PROJECT_ROOT/scripts/deploy_upgrade.sh"
    run_upgrade
}

# 执行数据库内外网配置
do_config_network() {
    source "$PROJECT_ROOT/scripts/config_network.sh"
    configure_network
}

# 执行防火墙配置
do_config_firewall() {
    source "$PROJECT_ROOT/scripts/config_firewall.sh"
    firewall_menu
}

# 检查环境
check_environment() {
    log_info "检查运行环境..."
    
    # 检查是否在 Linux 上运行
    if [ "$(uname)" != "Linux" ]; then
        log_warn "此脚本设计用于 Linux 系统，当前系统: $(uname)"
        if ! confirm "是否继续？"; then
            exit 0
        fi
    fi
    
    # 检查是否有 bash 4.0+（需要关联数组支持）
    if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        log_warn "建议使用 Bash 4.0 或更高版本"
    fi
    
    log_success "环境检查完成"
}

# 初始化目录结构
do_init_directories() {
    print_title "初始化目录结构"
    
    init_directories
    
    log_success "目录结构已初始化"
    echo ""
    echo "请将安装包放置到以下目录："
    echo -e "  ${CYAN}新部署安装包:${NC} $DEPLOY_PACKAGES_DIR"
    echo -e "  ${CYAN}升级安装包:${NC}   $UPDATE_PACKAGES_DIR"
    echo ""
    
    # 显示需要的安装包
    echo -e "${YELLOW}新部署所需安装包:${NC}"
    echo "  - deploy_basic_suse*.run"
    echo "  - deploy_sie_*_mysql_*.run"
    echo "  - deploy_vss_*_mysql_*.run"
    echo "  - deploy_vim_web_*.run"
    echo "  - install-lkdc-*.bin"
    echo "  - install_hy_message_push_server_*.bin"
    echo "  - install_hy_file_server_*.bin"
    echo ""
    echo -e "${YELLOW}升级所需安装包:${NC}"
    echo "  - update_sie_*_mysql_*.run"
    echo "  - update_vss_*_mysql_*.run"
    echo "  - deploy_vim_web_*.run"
    echo "  - install-lkdc-*.bin"
}

# 交互式主菜单
run_menu() {
    while true; do
        show_menu
        echo -n "请选择操作 [0-7]: "
        read -r choice
        
        case "$choice" in
            1)
                do_deploy_new
                press_any_key
                ;;
            2)
                do_deploy_upgrade
                press_any_key
                ;;
            3)
                check_all_services
                press_any_key
                ;;
            4)
                list_all_packages
                press_any_key
                ;;
            5)
                do_config_network
                press_any_key
                ;;
            6)
                do_config_firewall
                ;;
            7)
                do_init_directories
                press_any_key
                ;;
            0)
                echo ""
                log_info "感谢使用，再见！"
                echo ""
                exit 0
                ;;
            *)
                log_error "无效选择，请重新输入"
                sleep 1
                ;;
        esac
    done
}

# 主函数
main() {
    # 初始化目录
    init_directories
    
    # 解析命令行参数
    case "${1:-}" in
        -n|--new)
            check_environment
            do_deploy_new
            ;;
        -u|--upgrade)
            check_environment
            do_deploy_upgrade
            ;;
        -s|--status)
            check_all_services
            ;;
        -l|--list)
            list_all_packages
            ;;
        -h|--help)
            show_help
            ;;
        -v|--version)
            show_version
            ;;
        "")
            # 无参数，显示交互式菜单
            run_menu
            ;;
        *)
            log_error "未知选项: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
