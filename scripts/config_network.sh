#!/bin/bash
#
# MySQL数据库内外网配置脚本
# 描述: 用于配置VSS相关表的外网IP和端口映射
#

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载配置和公共模块
# 注意：端口默认值在 config.sh 中定义
source "$PROJECT_ROOT/config.sh"
source "$PROJECT_ROOT/lib/common.sh"

# 配置数据库内外网
configure_network() {
    print_title "数据库内外网配置"
    
    # 检查root权限
    check_root
    
    echo ""
    echo -e "${CYAN}=== MySQL数据库连接配置 ===${NC}"
    echo ""
    
    read -p "MySQL主机地址 [默认: $DEFAULT_MYSQL_HOST]: " MYSQL_HOST
    MYSQL_HOST=${MYSQL_HOST:-$DEFAULT_MYSQL_HOST}

    read -p "MySQL端口 [默认: $DEFAULT_MYSQL_PORT]: " MYSQL_PORT
    MYSQL_PORT=${MYSQL_PORT:-$DEFAULT_MYSQL_PORT}

    read -p "MySQL用户名 [默认: $DEFAULT_MYSQL_USER]: " MYSQL_USER
    MYSQL_USER=${MYSQL_USER:-$DEFAULT_MYSQL_USER}

    read -s -p "MySQL密码: " MYSQL_PASS
    echo

    read -p "数据库名称 [默认: sdedb]: " MYSQL_DB
    MYSQL_DB=${MYSQL_DB:-sdedb}

    echo ""
    echo -e "${CYAN}=== 网络配置 ===${NC}"
    echo ""
    
    read -p "公网IP地址: " PUBLIC_IP
    if [ -z "$PUBLIC_IP" ]; then
        log_error "公网IP地址不能为空"
        return 1
    fi
    
    read -p "内网IP地址: " PRIVATE_IP
    if [ -z "$PRIVATE_IP" ]; then
        log_error "内网IP地址不能为空"
        return 1
    fi

    echo ""
    echo -e "${CYAN}=== 端口配置 ===${NC}"
    echo -e "${YELLOW}提示: 直接回车使用默认值${NC}"
    echo ""

    read -p "MTN_NAT端口 [默认: $DEFAULT_MTN_NAT_PORT]: " MTN_NAT_PORT
    MTN_NAT_PORT=${MTN_NAT_PORT:-$DEFAULT_MTN_NAT_PORT}

    read -p "MTN_VIDEO_NAT端口 [默认: $DEFAULT_MTN_VIDEO_NAT_PORT]: " MTN_VIDEO_NAT_PORT
    MTN_VIDEO_NAT_PORT=${MTN_VIDEO_NAT_PORT:-$DEFAULT_MTN_VIDEO_NAT_PORT}

    read -p "MTN_AUDIO_NAT端口 [默认: $DEFAULT_MTN_AUDIO_NAT_PORT]: " MTN_AUDIO_NAT_PORT
    MTN_AUDIO_NAT_PORT=${MTN_AUDIO_NAT_PORT:-$DEFAULT_MTN_AUDIO_NAT_PORT}

    read -p "PUNCH端口 [默认: $DEFAULT_PUNCH_PORT]: " PUNCH_PORT
    PUNCH_PORT=${PUNCH_PORT:-$DEFAULT_PUNCH_PORT}

    read -p "SIE_NAT端口 [默认: $DEFAULT_SIE_NAT_PORT]: " SIE_NAT_PORT
    SIE_NAT_PORT=${SIE_NAT_PORT:-$DEFAULT_SIE_NAT_PORT}

    read -p "PROXY端口 [默认: $DEFAULT_PROXY_PORT]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-$DEFAULT_PROXY_PORT}

    read -p "PROXY_TLS端口 [默认: $DEFAULT_PROXY_TLS_PORT]: " PROXY_TLS_PORT
    PROXY_TLS_PORT=${PROXY_TLS_PORT:-$DEFAULT_PROXY_TLS_PORT}

    read -p "PROXY_HTTP端口 [默认: $DEFAULT_PROXY_HTTP_PORT]: " PROXY_HTTP_PORT
    PROXY_HTTP_PORT=${PROXY_HTTP_PORT:-$DEFAULT_PROXY_HTTP_PORT}

    read -p "PROXY_HTTPS端口 [默认: $DEFAULT_PROXY_HTTPS_PORT]: " PROXY_HTTPS_PORT
    PROXY_HTTPS_PORT=${PROXY_HTTPS_PORT:-$DEFAULT_PROXY_HTTPS_PORT}

    # 显示配置摘要
    echo ""
    print_title "配置摘要"
    echo -e "MySQL连接: ${CYAN}${MYSQL_USER}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}${NC}"
    echo -e "公网IP: ${GREEN}$PUBLIC_IP${NC}"
    echo -e "内网IP: ${GREEN}$PRIVATE_IP${NC}"
    echo ""
    echo "端口配置:"
    echo -e "  MTN_NAT:      ${CYAN}$MTN_NAT_PORT${NC}"
    echo -e "  MTN_VIDEO:    ${CYAN}$MTN_VIDEO_NAT_PORT${NC}"
    echo -e "  MTN_AUDIO:    ${CYAN}$MTN_AUDIO_NAT_PORT${NC}"
    echo -e "  PUNCH:        ${CYAN}$PUNCH_PORT${NC}"
    echo -e "  SIE_NAT:      ${CYAN}$SIE_NAT_PORT${NC}"
    echo -e "  PROXY:        ${CYAN}$PROXY_PORT${NC}"
    echo -e "  PROXY_TLS:    ${CYAN}$PROXY_TLS_PORT${NC}"
    echo -e "  PROXY_HTTP:   ${CYAN}$PROXY_HTTP_PORT${NC}"
    echo -e "  PROXY_HTTPS:  ${CYAN}$PROXY_HTTPS_PORT${NC}"
    echo ""

    if ! confirm "确认以上配置？"; then
        log_info "用户取消操作"
        return 0
    fi

    # 创建临时SQL文件
    local SQL_FILE=$(mktemp /tmp/mysql_config.XXXXXX)

    # 写入SQL语句到临时文件
    cat > "$SQL_FILE" << EOF
-- 配置t_domain_info
UPDATE t_domain_info SET DOMAIN_NAT_IP = '$PUBLIC_IP' WHERE DOMAIN_ID = 1;

-- 配置t_cmg_listen
UPDATE t_cmg_listen SET CMG_NAT_IPADDR = '$PUBLIC_IP' WHERE NODE_ID = 1;

-- 配置t_forwarding_config
UPDATE t_forwarding_config SET 
    MTN_NAT_IP = '$PUBLIC_IP',
    MTN_NAT_PORT = $MTN_NAT_PORT,
    MTN_VIDEO_NAT_PORT = $MTN_VIDEO_NAT_PORT,
    MTN_AUDIO_NAT_PORT = $MTN_AUDIO_NAT_PORT
WHERE NODE_ID = 1;

-- 配置t_punch_client_config
DELETE FROM t_punch_client_config WHERE SIE_IP = '0.0.0.0' AND PUNCH_IP = '0.0.0.0' AND PUNCH_PORT = 9009;
INSERT INTO t_punch_client_config (SIE_IP, PUNCH_IP, PUNCH_PORT) VALUES ('$PUBLIC_IP', '$PUBLIC_IP', $PUNCH_PORT);

-- 配置vss_domain_info
UPDATE vss_domain_info SET SIE_IP = '$PRIVATE_IP', SIE_NAT_PORT = $SIE_NAT_PORT WHERE ID = 1;

-- 配置vss_proxy_address
DELETE FROM vss_proxy_address WHERE PROXY_ADDR = '0.0.0.0' AND PROXY_IP = '0.0.0.0';
INSERT INTO vss_proxy_address (PROXY_ADDR, PROXY_PORT, PROXY_TLS_PORT, PROXY_HTTP_PORT, PROXY_IP, PROXY_HTTPS_PORT)
VALUES ('$PUBLIC_IP', $PROXY_PORT, $PROXY_TLS_PORT, $PROXY_HTTP_PORT, '$PUBLIC_IP', $PROXY_HTTPS_PORT);
EOF

    # 执行SQL语句
    log_info "正在执行数据库配置..."
    
    if mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" < "$SQL_FILE" 2>&1; then
        log_success "数据库配置成功完成!"
        
        # 显示配置结果
        echo ""
        log_info "验证配置结果..."
        echo ""
        
        echo -e "${CYAN}>>> t_domain_info <<<${NC}"
        mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -e "SELECT * FROM t_domain_info;" 2>/dev/null
        echo ""
        
        echo -e "${CYAN}>>> t_cmg_listen <<<${NC}"
        mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -e "SELECT * FROM t_cmg_listen;" 2>/dev/null
        echo ""
        
        echo -e "${CYAN}>>> t_forwarding_config <<<${NC}"
        mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -e "SELECT * FROM t_forwarding_config;" 2>/dev/null
        echo ""
        
        echo -e "${CYAN}>>> t_punch_client_config <<<${NC}"
        mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -e "SELECT * FROM t_punch_client_config;" 2>/dev/null
        echo ""
        
        echo -e "${CYAN}>>> vss_domain_info <<<${NC}"
        mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -e "SELECT * FROM vss_domain_info;" 2>/dev/null
        echo ""
        
        echo -e "${CYAN}>>> vss_proxy_address <<<${NC}"
        mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -e "SELECT * FROM vss_proxy_address;" 2>/dev/null
        
    else
        log_error "数据库配置失败，请检查错误信息"
        rm -f "$SQL_FILE"
        return 1
    fi

    # 清理临时文件
    rm -f "$SQL_FILE"
    
    return 0
}

# 主函数
main() {
    configure_network
    exit $?
}

# 如果直接运行此脚本，执行main函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
