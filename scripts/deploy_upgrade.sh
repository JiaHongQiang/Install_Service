#!/bin/bash
#
# 升级安装脚本
# 按顺序升级所有需要更新的服务
#

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载配置和模块
source "$PROJECT_ROOT/config.sh"
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/package_matcher.sh"
source "$PROJECT_ROOT/lib/service_checker.sh"
source "$PROJECT_ROOT/lib/cert_manager.sh"

# 安装单个升级包
# 参数: $1=包类型key, $2=描述, $3=额外参数
upgrade_package() {
    local package_key="$1"
    local description="$2"
    local extra_args="$3"
    
    print_separator
    log_info "开始升级: $description"
    
    # 查找安装包
    # 注意：deploy_vim_web 包在 deploy 目录，因为新旧部署共用
    local package_path
    local search_dir="$UPDATE_PACKAGES_DIR"
    
    if [[ "$package_key" == deploy_* ]]; then
        search_dir="$DEPLOY_PACKAGES_DIR"
        log_info "注意: $package_key 使用 deploy 目录的安装包"
    fi
    
    package_path=$(find_package "$search_dir" "$package_key")
    
    if [ $? -ne 0 ] || [ -z "$package_path" ]; then
        log_error "未找到 $description 的升级包"
        return 1
    fi
    
    log_info "找到升级包: $(basename "$package_path")"
    
    # 设置可执行权限
    chmod +x "$package_path"
    
    # 检查是否是 install 系列包（可能需要交互）
    local is_install_package=false
    if [[ "$package_key" == install_* ]]; then
        is_install_package=true
    fi
    
    # 执行升级
    log_info "正在执行升级..."
    log_info "注意：升级包自带自动备份功能，无需手动备份"
    
    if [ -n "$extra_args" ]; then
        log_info "使用参数: $extra_args"
    fi
    
    # 对于 install 系列包，可能需要交互
    if [ "$is_install_package" = true ]; then
        log_warn "此升级包可能需要交互操作，请注意屏幕提示"
        
        if [ -n "$extra_args" ]; then
            "$package_path" $extra_args
        else
            "$package_path"
        fi
    else
        if [ -n "$extra_args" ]; then
            "$package_path" $extra_args
        else
            "$package_path"
        fi
    fi
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_success "$description 升级完成"
    else
        log_error "$description 升级失败 (退出码: $exit_code)"
        return $exit_code
    fi
    
    return 0
}

# 执行升级
run_upgrade() {
    print_title "开始升级安装"
    
    # 检查root权限
    check_root
    
    # 初始化目录
    init_directories
    
    # 检查安装包
    log_info "检查升级包..."
    if ! check_upgrade_packages "$UPDATE_PACKAGES_DIR"; then
        die "升级包检查失败，请确保所有必要的升级包都已放置在 $UPDATE_PACKAGES_DIR 目录"
    fi
    
    # 显示当前服务状态
    log_info "检查当前服务状态..."
    check_upgrade_services
    
    # 显示安装包列表
    list_upgrade_packages "$UPDATE_PACKAGES_DIR" "$DEPLOY_PACKAGES_DIR"
    
    # 确认升级
    echo ""
    log_info "升级说明："
    echo -e "  ${CYAN}• 升级包自带自动备份功能，无需手动备份${NC}"
    echo -e "  ${CYAN}• 升级过程中服务可能会短暂中断${NC}"
    echo ""
    
    if ! confirm "确认开始升级安装？"; then
        log_info "用户取消升级"
        exit 0
    fi
    
    echo ""
    log_info "开始升级流程..."
    echo ""
    
    local failed=0
    local install_info
    local package_key
    local description
    local extra_args
    
    for install_info in "${UPGRADE_ORDER[@]}"; do
        # 解析安装信息
        IFS=':' read -r package_key description extra_args <<< "$install_info"
        
        if ! upgrade_package "$package_key" "$description" "$extra_args"; then
            ((failed++))
            log_error "升级 $description 失败"
            
            if ! confirm "是否继续升级其他组件？"; then
                log_info "用户选择停止升级"
                break
            fi
        fi
        
        echo ""
    done
    
    # 升级完成，检查服务状态
    print_title "升级完成"
    
    if [ $failed -gt 0 ]; then
        log_warn "升级过程中有 $failed 个组件失败"
    else
        log_success "所有组件升级成功"
    fi
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 5
    
    # 检查服务状态
    check_upgrade_services
    
    # 更新证书（可选，证书放在 deploy 目录，新旧共用）
    print_separator
    upgrade_certificates "$DEPLOY_PACKAGES_DIR"
    
    # 最终服务状态检查
    print_title "最终服务状态检查"
    check_upgrade_services
    
    return $failed
}

# 主函数
main() {
    run_upgrade
    exit $?
}

# 如果直接运行此脚本，执行main函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
