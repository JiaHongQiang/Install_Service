#!/bin/bash
#
# 新部署安装脚本
# 按顺序安装所有新部署所需的服务
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

# 安装单个包
# 参数: $1=包类型key, $2=描述, $3=额外参数
install_package() {
    local package_key="$1"
    local description="$2"
    local extra_args="$3"
    
    print_separator
    log_info "开始安装: $description"
    
    # 查找安装包
    local package_path
    package_path=$(find_package "$DEPLOY_PACKAGES_DIR" "$package_key")
    
    if [ $? -ne 0 ] || [ -z "$package_path" ]; then
        log_error "未找到 $description 的安装包"
        return 1
    fi
    
    log_info "找到安装包: $(basename "$package_path")"
    
    # 设置可执行权限
    chmod +x "$package_path"
    
    # 检查是否是 install 系列包（可能需要交互）
    local is_install_package=false
    if [[ "$package_key" == install_* ]]; then
        is_install_package=true
    fi
    
    # 执行安装
    log_info "正在执行安装..."
    
    if [ -n "$extra_args" ]; then
        log_info "使用参数: $extra_args"
    fi
    
    # 对于 install 系列包，使用 script 命令记录输出以便用户查看交互信息
    if [ "$is_install_package" = true ]; then
        log_warn "此安装包可能需要交互操作，请注意屏幕提示"
        
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
        log_success "$description 安装完成"
    else
        log_error "$description 安装失败 (退出码: $exit_code)"
        return $exit_code
    fi
    
    return 0
}

# 导入数据库脚本
import_database() {
    local db_script="$DEPLOY_PACKAGES_DIR/$DB_SCRIPT_NAME"
    
    print_title "导入数据库脚本"
    
    # 检查数据库脚本是否存在
    if [ ! -f "$db_script" ]; then
        log_error "数据库脚本不存在: $db_script"
        log_warn "请将 $DB_SCRIPT_NAME 放置到 $DEPLOY_PACKAGES_DIR 目录"
        return 1
    fi
    
    log_info "找到数据库脚本: $db_script"
    log_info "目标数据库: $DATABASE_NAME"
    
    # 确认导入
    if ! confirm "是否导入数据库脚本到 $DATABASE_NAME？"; then
        log_info "用户跳过数据库导入"
        return 0
    fi
    
    # 检查 MySQL 是否可用
    if ! command -v mysql &> /dev/null; then
        log_error "MySQL 客户端未安装或不在 PATH 中"
        return 1
    fi
    
    # 执行数据库导入
    log_info "正在导入数据库脚本..."
    
    # 使用 MySQL 命令导入
    if mysql -uroot -p"$MYSQL_PASSWORD" "$DATABASE_NAME" < "$db_script" 2>&1; then
        log_success "数据库脚本导入成功"
        
        # 导入成功后重启 SIE 和 VSS 服务
        print_separator
        log_info "重启 SIE 和 VSS 服务以使数据库更改生效..."
        
        # 重启 SIE 服务
        log_info "重启 SIE 服务..."
        if service sie restart; then
            log_success "SIE 服务重启成功"
        else
            log_error "SIE 服务重启失败"
        fi
        
        # 重启 VSS 服务
        log_info "重启 VSS 服务..."
        if service vss restart; then
            log_success "VSS 服务重启成功"
        else
            log_error "VSS 服务重启失败"
        fi
        
        # 等待服务重启完成
        log_info "等待服务重启完成..."
        sleep 5
        
        # 再次检查服务状态
        log_info "检查服务状态..."
        check_specified_services "sie" "vss"
        
        return 0
    else
        log_error "数据库脚本导入失败"
        log_warn "请检查数据库连接和脚本内容"
        return 1
    fi
}

# 执行新部署
run_deploy() {
    print_title "开始新部署安装"
    
    # 检查root权限
    check_root
    
    # 初始化目录
    init_directories
    
    # 检查安装包
    log_info "检查安装包..."
    if ! check_deploy_packages "$DEPLOY_PACKAGES_DIR"; then
        die "安装包检查失败，请确保所有必要的安装包都已放置在 $DEPLOY_PACKAGES_DIR 目录"
    fi
    
    # 显示安装包列表
    list_deploy_packages "$DEPLOY_PACKAGES_DIR"
    
    # 确认安装
    echo ""
    if ! confirm "确认开始新部署安装？"; then
        log_info "用户取消安装"
        exit 0
    fi
    
    echo ""
    log_info "开始安装流程..."
    echo ""
    
    local failed=0
    local install_info
    local package_key
    local description
    local extra_args
    
    for install_info in "${DEPLOY_ORDER[@]}"; do
        # 解析安装信息
        IFS=':' read -r package_key description extra_args <<< "$install_info"
        
        if ! install_package "$package_key" "$description" "$extra_args"; then
            ((failed++))
            log_error "安装 $description 失败"
            
            if ! confirm "是否继续安装其他组件？"; then
                log_info "用户选择停止安装"
                break
            fi
        fi
        
        echo ""
    done
    
    # 安装完成，检查服务状态
    print_title "安装完成"
    
    if [ $failed -gt 0 ]; then
        log_warn "安装过程中有 $failed 个组件失败"
    else
        log_success "所有组件安装成功"
    fi
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 5
    
    # 检查服务状态
    check_deploy_services
    
    # 部署 Nginx 配置和证书
    print_separator
    deploy_nginx_config "$DEPLOY_PACKAGES_DIR"
    
    print_separator
    deploy_certificates "$DEPLOY_PACKAGES_DIR"
    
    # 导入数据库脚本
    print_separator
    import_database
    
    # 最终服务状态检查
    print_title "最终服务状态检查"
    check_deploy_services
    
    return $failed
}

# 主函数
main() {
    run_deploy
    exit $?
}

# 如果直接运行此脚本，执行main函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
