#!/bin/bash
#
# 证书和Nginx配置管理模块
# 处理证书复制和Nginx配置替换
#

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "$SCRIPT_DIR/common.sh"

# 复制证书文件到目标目录
# 参数: $1=源文件, $2=目标目录
copy_cert_file() {
    local src_file="$1"
    local dest_dir="$2"
    local file_name=$(basename "$src_file")
    local dest_file="$dest_dir/$file_name"
    
    # 检查目标目录是否存在
    if [ ! -d "$dest_dir" ]; then
        log_warn "目标目录不存在: $dest_dir，尝试创建..."
        mkdir -p "$dest_dir"
    fi
    
    # 复制文件
    if cp "$src_file" "$dest_dir"; then
        log_success "$file_name 已复制到 $dest_dir"
        return 0
    else
        log_error "$file_name 复制到 $dest_dir 失败"
        return 1
    fi
}

# 部署证书
# 参数: $1=证书源目录
deploy_certificates() {
    local cert_dir="$1"
    
    print_title "部署证书文件"
    
    local success=0
    local failed=0
    
    for cert_file in "${CERT_FILES[@]}"; do
        local src_file="$cert_dir/$cert_file"
        
        if [ ! -f "$src_file" ]; then
            log_warn "证书文件不存在: $src_file，跳过"
            continue
        fi
        
        log_info "处理证书: $cert_file"
        
        # 复制到 Nginx 配置目录
        if copy_cert_file "$src_file" "$CERT_DEST_NGINX"; then
            ((success++))
        else
            ((failed++))
        fi
        
        # 复制到媒体服务器目录
        if copy_cert_file "$src_file" "$CERT_DEST_MEDIA"; then
            ((success++))
        else
            ((failed++))
        fi
        
        # root.crt 额外复制到 VSS 目录
        if [ "$cert_file" = "root.crt" ]; then
            if copy_cert_file "$src_file" "$CERT_DEST_VSS"; then
                ((success++))
            else
                ((failed++))
            fi
        fi
    done
    
    echo ""
    if [ $failed -eq 0 ] && [ $success -gt 0 ]; then
        log_success "证书部署完成，共复制 $success 个文件"
        return 0
    elif [ $success -eq 0 ]; then
        log_warn "未找到任何证书文件"
        return 1
    else
        log_warn "证书部署完成，成功 $success 个，失败 $failed 个"
        return 1
    fi
}

# 部署 Nginx 配置文件
# 参数: $1=配置文件源目录
deploy_nginx_config() {
    local src_dir="$1"
    local src_file="$src_dir/$NGINX_CONF_NAME"
    
    print_title "部署 Nginx 配置"
    
    # 检查源文件是否存在
    if [ ! -f "$src_file" ]; then
        log_warn "Nginx 配置文件不存在: $src_file"
        return 1
    fi
    
    log_info "找到 Nginx 配置文件: $src_file"
    log_info "目标目录: $NGINX_CONF_DIR"
    
    # 检查目标目录
    if [ ! -d "$NGINX_CONF_DIR" ]; then
        log_warn "Nginx 配置目录不存在: $NGINX_CONF_DIR"
        return 1
    fi
    
    # 复制配置文件
    if cp "$src_file" "$NGINX_CONF_DIR/"; then
        log_success "Nginx 配置文件已复制到 $NGINX_CONF_DIR"
    else
        log_error "Nginx 配置文件复制失败"
        return 1
    fi
    
    # 创建 SSL 密码文件
    create_ssl_password_file
    
    # 重启 Nginx 服务
    log_info "重启 Nginx 服务..."
    if service nginxd restart 2>/dev/null || service nginx restart 2>/dev/null; then
        log_success "Nginx 服务重启成功"
    else
        log_warn "Nginx 服务重启失败，请手动检查"
    fi
    
    return 0
}

# 创建 SSL 密码文件
create_ssl_password_file() {
    local password_file="$NGINX_CONF_DIR/$SSL_PASSWORD_FILE"
    
    log_info "创建 SSL 密码文件: $password_file"
    
    # 写入密码
    echo "$SSL_PASSWORD" > "$password_file"
    
    if [ $? -eq 0 ]; then
        # 设置权限
        chmod 600 "$password_file"
        log_success "SSL 密码文件创建成功"
        return 0
    else
        log_error "SSL 密码文件创建失败"
        return 1
    fi
}

# 执行完整的配置部署（新部署时调用）
# 参数: $1=配置源目录
deploy_configs_and_certs() {
    local src_dir="$1"
    
    # 部署 Nginx 配置
    deploy_nginx_config "$src_dir"
    
    # 部署证书
    deploy_certificates "$src_dir"
}

# 仅部署证书（升级时调用）
# 参数: $1=证书源目录
upgrade_certificates() {
    local cert_dir="$1"
    
    # 检查是否有证书需要更新
    local has_certs=false
    for cert_file in "${CERT_FILES[@]}"; do
        if [ -f "$cert_dir/$cert_file" ]; then
            has_certs=true
            break
        fi
    done
    
    if [ "$has_certs" = true ]; then
        if confirm "是否更新证书文件？"; then
            deploy_certificates "$cert_dir"
            
            # 证书更新后重启 Nginx
            log_info "重启 Nginx 服务..."
            if service nginxd restart 2>/dev/null || service nginx restart 2>/dev/null; then
                log_success "Nginx 服务重启成功"
            else
                log_warn "Nginx 服务重启失败，请手动检查"
            fi
        else
            log_info "跳过证书更新"
        fi
    else
        log_info "未找到证书文件，跳过证书部署"
    fi
}
