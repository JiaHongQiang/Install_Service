#!/bin/bash
#
# SUSE 12 SP5 防火墙端口管理脚本
# 使用 SuSEfirewall2 管理防火墙规则
#

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载配置和公共模块
source "$PROJECT_ROOT/config.sh"
source "$PROJECT_ROOT/lib/common.sh"

# 记录操作信息的函数
log_firewall_operation() {
    local operation=$1
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")
    local user=$USER
    echo "[${timestamp} UTC] User: ${user} - Operation: ${operation}" >> /var/log/firewall_operations.log 2>/dev/null
}

# 检查防火墙服务状态
check_firewall_service() {
    if ! systemctl is-active --quiet SuSEfirewall2; then
        log_warn "SuSEfirewall2 服务未运行，正在启动..."
        systemctl start SuSEfirewall2
        if [ $? -eq 0 ]; then
            log_success "SuSEfirewall2 服务启动成功"
            sleep 1
        else
            log_error "SuSEfirewall2 服务启动失败"
            return 1
        fi
    fi
    return 0
}

# 备份当前防火墙配置
backup_firewall_config() {
    local backup_dir="/etc/sysconfig/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp /etc/sysconfig/SuSEfirewall2 "$backup_dir/"
    log_info "防火墙配置已备份到: $backup_dir"
}

# 验证端口号
validate_port() {
    local port=$1
    if [[ ! $port =~ ^[0-9]+$ ]] || [ $port -lt 1 ] || [ $port -gt 65535 ]; then
        log_error "无效的端口号: $port (范围: 1-65535)"
        return 1
    fi
    return 0
}

# 验证端口列表
validate_port_list() {
    local ports=$1
    IFS=',' read -ra port_array <<< "$ports"
    for port in "${port_array[@]}"; do
        if [[ ! $port =~ ^[0-9]+$ ]] || [ $port -lt 1 ] || [ $port -gt 65535 ]; then
            log_error "无效的端口号: $port (范围: 1-65535)"
            return 1
        fi
    done
    return 0
}

# 验证协议
validate_protocol() {
    local protocol=$1
    if [[ ! $protocol =~ ^(tcp|udp|both)$ ]]; then
        log_error "无效的协议: $protocol (支持: tcp, udp, both)"
        return 1
    fi
    return 0
}

# 验证区域
validate_zone() {
    local zone=$1
    if [[ ! $zone =~ ^(EXT|INT|DMZ)$ ]]; then
        log_error "无效的区域: $zone (支持: EXT, INT, DMZ)"
        return 1
    fi
    return 0
}

# 开放端口
open_ports() {
    local ports=$1
    local protocol=$2
    local zone=${3:-"EXT"}
    
    validate_port_list "$ports" || return 1
    validate_protocol "$protocol" || return 1
    validate_zone "$zone" || return 1
    
    IFS=',' read -ra port_array <<< "$ports"
    log_info "开放端口: ${port_array[*]} ($protocol) 在区域 $zone"
    
    for port in "${port_array[@]}"; do
        if [[ $protocol == "tcp" ]] || [[ $protocol == "both" ]]; then
            if grep -q "FW_SERVICES_${zone}_TCP.*\b$port\b" /etc/sysconfig/SuSEfirewall2; then
                log_warn "TCP端口 $port 已经开放"
            else
                current_tcp=$(grep "^FW_SERVICES_${zone}_TCP=" /etc/sysconfig/SuSEfirewall2 | cut -d'"' -f2)
                new_tcp="${current_tcp:+$current_tcp }$port"
                sed -i "s/^FW_SERVICES_${zone}_TCP=.*/FW_SERVICES_${zone}_TCP=\"$new_tcp\"/" /etc/sysconfig/SuSEfirewall2
                log_success "TCP端口 $port 添加成功"
                log_firewall_operation "开放 TCP 端口 $port (区域: $zone)"
            fi
        fi
        
        if [[ $protocol == "udp" ]] || [[ $protocol == "both" ]]; then
            if grep -q "FW_SERVICES_${zone}_UDP.*\b$port\b" /etc/sysconfig/SuSEfirewall2; then
                log_warn "UDP端口 $port 已经开放"
            else
                current_udp=$(grep "^FW_SERVICES_${zone}_UDP=" /etc/sysconfig/SuSEfirewall2 | cut -d'"' -f2)
                new_udp="${current_udp:+$current_udp }$port"
                sed -i "s/^FW_SERVICES_${zone}_UDP=.*/FW_SERVICES_${zone}_UDP=\"$new_udp\"/" /etc/sysconfig/SuSEfirewall2
                log_success "UDP端口 $port 添加成功"
                log_firewall_operation "开放 UDP 端口 $port (区域: $zone)"
            fi
        fi
    done
}

# 关闭端口
close_ports() {
    local ports=$1
    local protocol=$2
    local zone=${3:-"EXT"}
    
    validate_port_list "$ports" || return 1
    validate_protocol "$protocol" || return 1
    validate_zone "$zone" || return 1
    
    IFS=',' read -ra port_array <<< "$ports"
    log_info "关闭端口: ${port_array[*]} ($protocol) 在区域 $zone"
    
    for port in "${port_array[@]}"; do
        if [[ $protocol == "tcp" ]] || [[ $protocol == "both" ]]; then
            if grep -q "FW_SERVICES_${zone}_TCP.*\b$port\b" /etc/sysconfig/SuSEfirewall2; then
                current_tcp=$(grep "^FW_SERVICES_${zone}_TCP=" /etc/sysconfig/SuSEfirewall2 | cut -d'"' -f2)
                new_tcp=$(echo "$current_tcp" | sed "s/\b$port\b//g" | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
                sed -i "s/^FW_SERVICES_${zone}_TCP=.*/FW_SERVICES_${zone}_TCP=\"$new_tcp\"/" /etc/sysconfig/SuSEfirewall2
                log_success "TCP端口 $port 移除成功"
                log_firewall_operation "关闭 TCP 端口 $port (区域: $zone)"
            else
                log_warn "TCP端口 $port 未找到"
            fi
        fi
        
        if [[ $protocol == "udp" ]] || [[ $protocol == "both" ]]; then
            if grep -q "FW_SERVICES_${zone}_UDP.*\b$port\b" /etc/sysconfig/SuSEfirewall2; then
                current_udp=$(grep "^FW_SERVICES_${zone}_UDP=" /etc/sysconfig/SuSEfirewall2 | cut -d'"' -f2)
                new_udp=$(echo "$current_udp" | sed "s/\b$port\b//g" | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
                sed -i "s/^FW_SERVICES_${zone}_UDP=.*/FW_SERVICES_${zone}_UDP=\"$new_udp\"/" /etc/sysconfig/SuSEfirewall2
                log_success "UDP端口 $port 移除成功"
                log_firewall_operation "关闭 UDP 端口 $port (区域: $zone)"
            else
                log_warn "UDP端口 $port 未找到"
            fi
        fi
    done
}

# 重载防火墙配置
reload_firewall() {
    log_info "重载防火墙配置..."
    systemctl restart SuSEfirewall2
    
    local status=$(systemctl is-active SuSEfirewall2)
    if [ "$status" = "active" ]; then
        log_success "防火墙配置已成功重载"
        return 0
    else
        log_error "防火墙配置重载失败 - 服务状态: $status"
        return 1
    fi
}

# 显示当前开放的端口
show_open_ports() {
    local zone=${1:-"EXT"}
    validate_zone "$zone" || return 1
    
    print_title "当前开放的端口 (区域: $zone)"
    
    # 显示TCP端口
    tcp_ports=$(grep "^FW_SERVICES_${zone}_TCP=" /etc/sysconfig/SuSEfirewall2 | cut -d'"' -f2)
    if [ -n "$tcp_ports" ]; then
        echo -e "${GREEN}TCP端口:${NC} $tcp_ports"
    else
        echo -e "${YELLOW}TCP端口: 无${NC}"
    fi
    
    # 显示UDP端口
    udp_ports=$(grep "^FW_SERVICES_${zone}_UDP=" /etc/sysconfig/SuSEfirewall2 | cut -d'"' -f2)
    if [ -n "$udp_ports" ]; then
        echo -e "${GREEN}UDP端口:${NC} $udp_ports"
    else
        echo -e "${YELLOW}UDP端口: 无${NC}"
    fi
    
    echo ""
}

# 显示防火墙管理帮助
show_firewall_help() {
    echo ""
    echo -e "${CYAN}防火墙端口管理帮助${NC}"
    echo ""
    echo "命令格式:"
    echo "  open <端口> <协议> [区域]     - 开放端口(支持逗号分隔多个端口)"
    echo "  close <端口> <协议> [区域]    - 关闭端口(支持逗号分隔多个端口)"
    echo "  show [区域]                   - 显示开放的端口"
    echo "  reload                        - 重载防火墙配置"
    echo "  backup                        - 备份防火墙配置"
    echo ""
    echo "参数说明:"
    echo "  端口: 1-65535 之间的数字，多个端口用逗号分隔(如: 80,443,8080)"
    echo "  协议: tcp, udp, both"
    echo "  区域: EXT(外部,默认), INT(内部), DMZ(非军事区)"
    echo ""
}

# 交互式防火墙管理菜单
firewall_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}       ${GREEN}防火墙端口管理${NC}                   ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}1.${NC} 查看当前开放的端口               ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}2.${NC} 开放端口                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}3.${NC} 关闭端口                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}4.${NC} 重载防火墙配置                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}5.${NC} 备份防火墙配置                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}6.${NC} 帮助                             ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}0.${NC} 返回主菜单                       ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
        echo ""
        
        echo -n "请选择操作 [0-6]: "
        read -r choice
        
        case "$choice" in
            1)
                echo ""
                echo -n "请输入区域 (EXT/INT/DMZ) [默认: EXT]: "
                read -r zone
                zone=${zone:-EXT}
                show_open_ports "$zone"
                ;;
            2)
                check_firewall_service || continue
                echo ""
                echo -n "请输入要开放的端口 (多个用逗号分隔): "
                read -r ports
                echo -n "请输入协议 (tcp/udp/both): "
                read -r protocol
                echo -n "请输入区域 (EXT/INT/DMZ) [默认: EXT]: "
                read -r zone
                zone=${zone:-EXT}
                
                if [ -n "$ports" ] && [ -n "$protocol" ]; then
                    backup_firewall_config
                    open_ports "$ports" "$protocol" "$zone"
                    reload_firewall
                else
                    log_error "端口和协议不能为空"
                fi
                ;;
            3)
                check_firewall_service || continue
                echo ""
                echo -n "请输入要关闭的端口 (多个用逗号分隔): "
                read -r ports
                echo -n "请输入协议 (tcp/udp/both): "
                read -r protocol
                echo -n "请输入区域 (EXT/INT/DMZ) [默认: EXT]: "
                read -r zone
                zone=${zone:-EXT}
                
                if [ -n "$ports" ] && [ -n "$protocol" ]; then
                    backup_firewall_config
                    close_ports "$ports" "$protocol" "$zone"
                    reload_firewall
                else
                    log_error "端口和协议不能为空"
                fi
                ;;
            4)
                check_firewall_service && reload_firewall
                ;;
            5)
                backup_firewall_config
                ;;
            6)
                show_firewall_help
                ;;
            0)
                return 0
                ;;
            *)
                log_error "无效选择"
                ;;
        esac
        
        press_any_key
    done
}

# 主函数
main() {
    check_root
    firewall_menu
}

# 如果直接运行此脚本，执行main函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
