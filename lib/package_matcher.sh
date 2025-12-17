#!/bin/bash
#
# 包名模糊匹配模块
# 根据包名前缀和关键字匹配安装包，支持版本号排序选择最新版本
#

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "$SCRIPT_DIR/common.sh"

# 包名模式定义
declare -A PACKAGE_PATTERNS
PACKAGE_PATTERNS=(
    # 新部署包
    ["deploy_basic"]="deploy_basic_suse*.run"
    ["deploy_sie"]="deploy_sie_*_mysql_*.run"
    ["deploy_vss"]="deploy_vss_*_mysql_*.run"
    ["deploy_vim_web"]="deploy_vim_web_*.run"
    
    # 升级包
    ["update_sie"]="update_sie_*_mysql_*.run"
    ["update_vss"]="update_vss_*_mysql_*.run"
    
    # install系列包
    ["install_lkdc"]="install-lkdc-*.bin"
    ["install_message_push"]="install_hy_message_push_server_*.bin"
    ["install_file_server"]="install_hy_file_server_*.bin"
)

# 从文件名提取版本号
# 参数: $1=文件名
# 返回: 版本号字符串
extract_version() {
    local filename="$1"
    local version=""
    
    # 尝试匹配 V200R006B07 这种格式
    version=$(echo "$filename" | grep -oP 'V\d+R\d+[A-Z]\d+' | head -1)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi
    
    # 尝试匹配 V100R003B17 格式
    version=$(echo "$filename" | grep -oP 'V\d+R\d+B\d+' | head -1)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi
    
    # 尝试匹配 V100R001C01B23 格式
    version=$(echo "$filename" | grep -oP 'V\d+R\d+C\d+B\d+' | head -1)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi
    
    # 尝试匹配日期时间格式 20250618111517
    version=$(echo "$filename" | grep -oP '\d{14}' | head -1)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi
    
    # 尝试匹配日期格式 20250513
    version=$(echo "$filename" | grep -oP '\d{8}' | head -1)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi
    
    # 无法提取版本号，返回空
    echo ""
    return 1
}

# 比较版本号
# 参数: $1=版本1, $2=版本2
# 返回: 0=相等, 1=版本1大, 2=版本2大
compare_versions() {
    local v1="$1"
    local v2="$2"
    
    if [ "$v1" = "$v2" ]; then
        return 0
    fi
    
    # 使用sort -V进行版本排序
    local higher=$(echo -e "$v1\n$v2" | sort -V | tail -1)
    
    if [ "$higher" = "$v1" ]; then
        return 1
    else
        return 2
    fi
}

# 查找匹配的包（返回最新版本）
# 参数: $1=包目录, $2=包类型key
# 返回: 匹配的文件完整路径
find_package() {
    local package_dir="$1"
    local package_key="$2"
    local pattern="${PACKAGE_PATTERNS[$package_key]}"
    
    if [ -z "$pattern" ]; then
        log_error "未知的包类型: $package_key"
        return 1
    fi
    
    if [ ! -d "$package_dir" ]; then
        log_error "包目录不存在: $package_dir"
        return 1
    fi
    
    # 查找匹配的文件
    local matches=()
    while IFS= read -r -d '' file; do
        matches+=("$file")
    done < <(find "$package_dir" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
    
    local count=${#matches[@]}
    
    if [ $count -eq 0 ]; then
        log_warn "未找到匹配的包: $pattern (目录: $package_dir)"
        return 1
    elif [ $count -eq 1 ]; then
        echo "${matches[0]}"
        return 0
    else
        # 多个匹配，选择最新版本
        log_info "发现 $count 个匹配的包，选择最新版本..."
        
        local latest=""
        local latest_version=""
        local latest_mtime=0
        
        for file in "${matches[@]}"; do
            local filename=$(basename "$file")
            local version=$(extract_version "$filename")
            local mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
            
            if [ -n "$version" ] && [ -n "$latest_version" ]; then
                # 比较版本号
                compare_versions "$version" "$latest_version"
                local cmp_result=$?
                if [ $cmp_result -eq 1 ]; then
                    latest="$file"
                    latest_version="$version"
                    latest_mtime="$mtime"
                fi
            elif [ -n "$version" ]; then
                latest="$file"
                latest_version="$version"
                latest_mtime="$mtime"
            elif [ "$mtime" -gt "$latest_mtime" ]; then
                # 无法提取版本，使用修改时间
                latest="$file"
                latest_mtime="$mtime"
            fi
        done
        
        if [ -z "$latest" ]; then
            # 兜底：取第一个
            latest="${matches[0]}"
        fi
        
        log_info "选择版本: $(basename "$latest")"
        echo "$latest"
        return 0
    fi
}

# 列出所有可用的包（通用函数）
# 参数: $1=包目录, $2=要显示的key列表（空格分隔）
list_packages_by_keys() {
    local package_dir="$1"
    shift
    local keys=("$@")
    
    if [ ! -d "$package_dir" ]; then
        log_error "包目录不存在: $package_dir"
        return 1
    fi
    
    echo -e "${CYAN}目录: $package_dir${NC}"
    echo ""
    
    for key in "${keys[@]}"; do
        local pattern="${PACKAGE_PATTERNS[$key]}"
        if [ -z "$pattern" ]; then
            continue
        fi
        local found=$(find "$package_dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | head -1)
        
        if [ -n "$found" ]; then
            echo -e "  ${GREEN}✓${NC} $key: $(basename "$found")"
        else
            echo -e "  ${RED}✗${NC} $key: 未找到"
        fi
    done
    
    echo ""
}

# 列出新部署所需的包
# 参数: $1=包目录
list_deploy_packages() {
    local package_dir="$1"
    local deploy_keys=("deploy_basic" "deploy_sie" "deploy_vss" "deploy_vim_web" "install_lkdc" "install_message_push" "install_file_server")
    
    print_title "新部署安装包列表"
    list_packages_by_keys "$package_dir" "${deploy_keys[@]}"
}

# 列出升级所需的包
# 参数: $1=update目录, $2=deploy目录（可选，用于VIM_Web）
list_upgrade_packages() {
    local update_dir="$1"
    local deploy_dir="${2:-$(dirname "$update_dir")/deploy}"
    local update_keys=("update_sie" "update_vss" "install_lkdc")
    
    print_title "升级安装包列表"
    
    # 显示 update 目录的包
    echo -e "${CYAN}目录: $update_dir${NC}"
    echo ""
    
    for key in "${update_keys[@]}"; do
        local pattern="${PACKAGE_PATTERNS[$key]}"
        local found=$(find "$update_dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | head -1)
        
        if [ -n "$found" ]; then
            echo -e "  ${GREEN}✓${NC} $key: $(basename "$found")"
        else
            echo -e "  ${RED}✗${NC} $key: 未找到"
        fi
    done
    
    # VIM_Web 从 deploy 目录查找
    local vim_pattern="${PACKAGE_PATTERNS[deploy_vim_web]}"
    local vim_found=$(find "$deploy_dir" -maxdepth 1 -type f -name "$vim_pattern" 2>/dev/null | head -1)
    
    if [ -n "$vim_found" ]; then
        echo -e "  ${GREEN}✓${NC} deploy_vim_web: $(basename "$vim_found") ${YELLOW}(来自 deploy 目录)${NC}"
    else
        echo -e "  ${RED}✗${NC} deploy_vim_web: 未找到 (在 deploy 目录)"
    fi
    
    echo ""
}

# 列出所有可用的包（保留原函数用于兼容）
# 参数: $1=包目录
list_available_packages() {
    local package_dir="$1"
    
    if [ ! -d "$package_dir" ]; then
        log_error "包目录不存在: $package_dir"
        return 1
    fi
    
    print_title "可用安装包列表"
    
    echo -e "${CYAN}目录: $package_dir${NC}"
    echo ""
    
    for key in "${!PACKAGE_PATTERNS[@]}"; do
        local pattern="${PACKAGE_PATTERNS[$key]}"
        local found=$(find "$package_dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | head -1)
        
        if [ -n "$found" ]; then
            echo -e "  ${GREEN}✓${NC} $key: $(basename "$found")"
        else
            echo -e "  ${RED}✗${NC} $key: 未找到"
        fi
    done
    
    echo ""
}


# 检查新部署所需的包是否存在
# 参数: $1=包目录
check_deploy_packages() {
    local package_dir="$1"
    local missing=0
    local required_keys=("deploy_basic" "deploy_sie" "deploy_vss" "deploy_vim_web" "install_lkdc" "install_message_push" "install_file_server")
    
    log_info "检查新部署所需安装包..."
    
    for key in "${required_keys[@]}"; do
        if ! find_package "$package_dir" "$key" > /dev/null 2>&1; then
            log_error "缺少必要的安装包: $key"
            ((missing++))
        fi
    done
    
    if [ $missing -gt 0 ]; then
        log_error "缺少 $missing 个必要的安装包"
        return 1
    fi
    
    log_success "所有必要的安装包已就绪"
    return 0
}

# 检查升级所需的包是否存在
# 参数: $1=包目录
check_upgrade_packages() {
    local package_dir="$1"
    local missing=0
    # 注意：deploy_vim_web 在 deploy 目录，其他在 update 目录
    local update_keys=("update_sie" "update_vss" "install_lkdc")
    local deploy_keys=("deploy_vim_web")
    
    log_info "检查升级所需安装包..."
    
    # 检查 update 目录的包
    for key in "${update_keys[@]}"; do
        if ! find_package "$package_dir" "$key" > /dev/null 2>&1; then
            log_error "缺少必要的安装包: $key"
            ((missing++))
        fi
    done
    
    # 检查 deploy 目录的包（VIM_Web）
    local deploy_dir=$(dirname "$package_dir")/deploy
    for key in "${deploy_keys[@]}"; do
        if ! find_package "$deploy_dir" "$key" > /dev/null 2>&1; then
            log_error "缺少必要的安装包: $key (在 deploy 目录)"
            ((missing++))
        fi
    done
    
    if [ $missing -gt 0 ]; then
        log_error "缺少 $missing 个必要的安装包"
        return 1
    fi
    
    log_success "所有必要的安装包已就绪"
    return 0
}
