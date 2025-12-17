#!/bin/bash
#
# 服务状态检查模块
# 检查各个服务的运行状态
#

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "$SCRIPT_DIR/common.sh"

# 服务列表定义
SERVICES=(
    "sie:SIE服务"
    "vss:VSS服务"
    "lkdc:LKDC服务"
    "hy_message_push_server:消息推送服务"
    "hy_file_server:文件服务"
)

# 检查单个服务状态
# 参数: $1=服务名称
check_service_status() {
    local service_name="$1"
    local status_output
    local exit_code
    
    # 尝试使用 service 命令
    status_output=$(service "$service_name" status 2>&1)
    exit_code=$?
    
    # 判断服务状态
    if [ $exit_code -eq 0 ]; then
        # 进一步检查输出内容
        if echo "$status_output" | grep -qiE "running|active|started"; then
            return 0  # 服务运行中
        elif echo "$status_output" | grep -qiE "stopped|inactive|dead"; then
            return 1  # 服务已停止
        else
            return 0  # 默认认为运行中（因为exit_code为0）
        fi
    else
        # 检查是否服务不存在
        if echo "$status_output" | grep -qiE "not found|unrecognized|unknown"; then
            return 2  # 服务不存在
        fi
        return 1  # 服务已停止或异常
    fi
}

# 获取服务状态描述
# 参数: $1=服务名称
get_service_status_text() {
    local service_name="$1"
    
    check_service_status "$service_name"
    local result=$?
    
    case $result in
        0)
            echo -e "${GREEN}● 运行中${NC}"
            ;;
        1)
            echo -e "${RED}○ 已停止${NC}"
            ;;
        2)
            echo -e "${YELLOW}? 未安装${NC}"
            ;;
        *)
            echo -e "${RED}✗ 未知${NC}"
            ;;
    esac
}

# 检查所有服务状态
check_all_services() {
    print_title "服务状态检查"
    
    local all_running=true
    local service_info
    local service_name
    local service_desc
    
    printf "%-30s %s\n" "服务名称" "状态"
    echo "----------------------------------------"
    
    for service_info in "${SERVICES[@]}"; do
        service_name="${service_info%%:*}"
        service_desc="${service_info##*:}"
        
        local status_text=$(get_service_status_text "$service_name")
        printf "%-30s %b\n" "$service_desc ($service_name)" "$status_text"
        
        check_service_status "$service_name"
        if [ $? -ne 0 ]; then
            all_running=false
        fi
    done
    
    echo ""
    
    if [ "$all_running" = true ]; then
        log_success "所有服务运行正常"
        return 0
    else
        log_warn "部分服务未运行，请检查"
        return 1
    fi
}

# 检查指定服务列表状态
# 参数: $@=服务名称列表
check_specified_services() {
    local services=("$@")
    
    print_title "服务状态检查"
    
    local all_running=true
    
    printf "%-30s %s\n" "服务名称" "状态"
    echo "----------------------------------------"
    
    for service_name in "${services[@]}"; do
        local status_text=$(get_service_status_text "$service_name")
        printf "%-30s %b\n" "$service_name" "$status_text"
        
        check_service_status "$service_name"
        if [ $? -ne 0 ]; then
            all_running=false
        fi
    done
    
    echo ""
    
    if [ "$all_running" = true ]; then
        log_success "所有服务运行正常"
        return 0
    else
        log_warn "部分服务未运行，请检查"
        return 1
    fi
}

# 启动服务
# 参数: $1=服务名称
start_service() {
    local service_name="$1"
    
    log_info "启动服务: $service_name"
    service "$service_name" start
    
    # 等待服务启动
    sleep 2
    
    check_service_status "$service_name"
    if [ $? -eq 0 ]; then
        log_success "服务 $service_name 启动成功"
        return 0
    else
        log_error "服务 $service_name 启动失败"
        return 1
    fi
}

# 停止服务
# 参数: $1=服务名称
stop_service() {
    local service_name="$1"
    
    log_info "停止服务: $service_name"
    service "$service_name" stop
    
    # 等待服务停止
    sleep 2
    
    check_service_status "$service_name"
    if [ $? -ne 0 ]; then
        log_success "服务 $service_name 已停止"
        return 0
    else
        log_warn "服务 $service_name 可能未完全停止"
        return 1
    fi
}

# 重启服务
# 参数: $1=服务名称
restart_service() {
    local service_name="$1"
    
    log_info "重启服务: $service_name"
    service "$service_name" restart
    
    # 等待服务重启
    sleep 3
    
    check_service_status "$service_name"
    if [ $? -eq 0 ]; then
        log_success "服务 $service_name 重启成功"
        return 0
    else
        log_error "服务 $service_name 重启失败"
        return 1
    fi
}

# 新部署后检查服务
check_deploy_services() {
    log_info "检查新部署的服务状态..."
    check_specified_services "sie" "vss" "lkdc" "hy_message_push_server" "hy_file_server"
}

# 升级后检查服务
check_upgrade_services() {
    log_info "检查升级后的服务状态..."
    check_specified_services "sie" "vss" "lkdc"
}
