#!/bin/bash
#
# 公共函数库
# 提供日志输出、错误处理、用户交互等公共函数
#

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志级别
LOG_LEVEL_INFO="INFO"
LOG_LEVEL_WARN="WARN"
LOG_LEVEL_ERROR="ERROR"
LOG_LEVEL_SUCCESS="SUCCESS"

# 获取当前时间戳
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# 日志输出函数
# 参数: $1=日志级别, $2=消息内容
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(get_timestamp)
    local color=""
    
    case "$level" in
        "$LOG_LEVEL_INFO")
            color="$BLUE"
            ;;
        "$LOG_LEVEL_WARN")
            color="$YELLOW"
            ;;
        "$LOG_LEVEL_ERROR")
            color="$RED"
            ;;
        "$LOG_LEVEL_SUCCESS")
            color="$GREEN"
            ;;
        *)
            color="$NC"
            ;;
    esac
    
    echo -e "${color}[${timestamp}] [${level}] ${message}${NC}"
}

# 快捷日志函数
log_info() {
    log "$LOG_LEVEL_INFO" "$1"
}

log_warn() {
    log "$LOG_LEVEL_WARN" "$1"
}

log_error() {
    log "$LOG_LEVEL_ERROR" "$1"
}

log_success() {
    log "$LOG_LEVEL_SUCCESS" "$1"
}

# 打印分隔线
print_separator() {
    echo -e "${CYAN}========================================${NC}"
}

# 打印标题
print_title() {
    local title="$1"
    echo ""
    print_separator
    echo -e "${CYAN}  $title${NC}"
    print_separator
    echo ""
}

# 用户确认函数
# 参数: $1=提示消息
# 返回: 0=确认, 1=取消
confirm() {
    local message="$1"
    local response
    
    while true; do
        echo -e "${YELLOW}${message} [y/n]: ${NC}"
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            [nN]|[nN][oO])
                return 1
                ;;
            *)
                echo -e "${RED}请输入 y 或 n${NC}"
                ;;
        esac
    done
}

# 错误退出函数
# 参数: $1=错误消息, $2=退出码(可选,默认1)
die() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_error "$message"
    exit "$exit_code"
}

# 检查命令执行结果
# 参数: $1=命令描述
check_result() {
    local description="$1"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_success "$description 成功"
        return 0
    else
        log_error "$description 失败 (退出码: $exit_code)"
        return $exit_code
    fi
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        die "此脚本需要root权限运行，请使用 sudo 或以root用户执行"
    fi
}

# 检查文件是否存在
# 参数: $1=文件路径
check_file_exists() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        log_error "文件不存在: $file_path"
        return 1
    fi
    return 0
}

# 检查目录是否存在
# 参数: $1=目录路径
check_dir_exists() {
    local dir_path="$1"
    
    if [ ! -d "$dir_path" ]; then
        log_error "目录不存在: $dir_path"
        return 1
    fi
    return 0
}

# 设置文件可执行权限
# 参数: $1=文件路径
make_executable() {
    local file_path="$1"
    
    if [ -f "$file_path" ]; then
        chmod +x "$file_path"
        log_info "已设置可执行权限: $file_path"
    else
        log_warn "文件不存在，无法设置权限: $file_path"
        return 1
    fi
}

# 运行安装包
# 参数: $1=安装包路径, $2=额外参数(可选)
run_installer() {
    local installer_path="$1"
    local extra_args="$2"
    
    if [ ! -f "$installer_path" ]; then
        log_error "安装包不存在: $installer_path"
        return 1
    fi
    
    # 设置可执行权限
    chmod +x "$installer_path"
    
    log_info "开始执行安装包: $(basename "$installer_path")"
    log_info "完整路径: $installer_path"
    
    if [ -n "$extra_args" ]; then
        log_info "附加参数: $extra_args"
        "$installer_path" $extra_args
    else
        "$installer_path"
    fi
    
    return $?
}

# 等待用户按键继续
press_any_key() {
    echo ""
    echo -e "${YELLOW}按任意键继续...${NC}"
    read -n 1 -s -r
    echo ""
}
