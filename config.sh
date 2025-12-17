#!/bin/bash
#
# 配置文件
# 定义项目相关的配置参数
#

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===========================
# 目录配置
# ===========================

# 安装包根目录
PACKAGES_DIR="${PROJECT_ROOT}/packages"

# 新部署安装包目录
DEPLOY_PACKAGES_DIR="${PACKAGES_DIR}/deploy"

# 升级安装包目录
UPDATE_PACKAGES_DIR="${PACKAGES_DIR}/update"

# 日志目录
LOG_DIR="${PROJECT_ROOT}/logs"

# 日志文件
LOG_FILE="${LOG_DIR}/install_$(date +%Y%m%d_%H%M%S).log"

# ===========================
# 安装选项配置
# ===========================

# LKDC 安装前缀
LKDC_PREFIX="/home"

# 消息推送和文件服务安装参数
HY_SERVICE_PARAM="hy"

# 是否自动确认所有提示（对于install系列包）
AUTO_CONFIRM=${AUTO_CONFIRM:-false}

# ===========================
# 数据库配置
# ===========================

# MySQL 默认密码
MYSQL_PASSWORD="Huaiye@2020**"

# 数据库名称
DATABASE_NAME="sdedb"

# 数据库脚本相对路径（相对于 deploy 目录）
DB_SCRIPT_NAME="sdedb.sql"

# ===========================
# 服务配置
# ===========================

# 新部署需要检查的服务列表
DEPLOY_SERVICES=("sie" "vss" "lkdc" "hy_message_push_server" "hy_file_server")

# 升级需要检查的服务列表
UPGRADE_SERVICES=("sie" "vss" "lkdc")

# ===========================
# 安装顺序配置
# ===========================

# 新部署安装顺序
DEPLOY_ORDER=(
    "deploy_basic:基础环境:"
    "deploy_sie:SIE服务:"
    "deploy_vss:VSS服务:"
    "deploy_vim_web:VIM_Web服务:"
    "install_lkdc:LKDC服务:--prefix=${LKDC_PREFIX}"
    "install_message_push:消息推送服务:${HY_SERVICE_PARAM}"
    "install_file_server:文件服务:${HY_SERVICE_PARAM}"
)

# 升级安装顺序
UPGRADE_ORDER=(
    "update_sie:SIE服务:"
    "update_vss:VSS服务:"
    "deploy_vim_web:VIM_Web服务:"
    "install_lkdc:LKDC服务:--prefix=${LKDC_PREFIX}"
)

# ===========================
# 函数：初始化目录
# ===========================
init_directories() {
    # 创建日志目录
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
    fi
    
    # 创建安装包目录
    if [ ! -d "$DEPLOY_PACKAGES_DIR" ]; then
        mkdir -p "$DEPLOY_PACKAGES_DIR"
    fi
    
    if [ ! -d "$UPDATE_PACKAGES_DIR" ]; then
        mkdir -p "$UPDATE_PACKAGES_DIR"
    fi
}
