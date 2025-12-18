# Linux 服务器安装部署服务

一键部署和升级 Linux 服务器上的多个服务模块（SIE、VSS、LKDC、VIM_Web、消息推送、文件服务）。

## 功能特性

- ✅ 支持新部署和升级两种安装模式
- ✅ 自动匹配最新版本的安装包（基于版本号或修改时间）
- ✅ 交互式菜单和命令行参数两种使用方式
- ✅ 安装完成后自动检查服务状态
- ✅ 彩色日志输出，便于查看安装进度
- ✅ 升级时可选择升级特定服务
- ✅ Nginx 配置和证书自动部署（可选）
- ✅ 数据库内外网配置工具

## 目录结构

```
Install_Service/
├── packages/                      # 安装包目录
│   ├── deploy/                    # 新部署安装包
│   └── update/                    # 升级安装包
├── lib/
│   ├── package_matcher.sh         # 包名模糊匹配模块
│   ├── service_checker.sh         # 服务状态检查模块
│   ├── cert_manager.sh            # 证书和Nginx配置管理
│   └── common.sh                  # 公共函数库
├── scripts/
│   ├── deploy_new.sh              # 新部署脚本
│   ├── deploy_upgrade.sh          # 升级安装脚本
│   └── config_network.sh          # 数据库内外网配置
├── logs/                          # 日志目录（自动创建）
├── install.sh                     # 主入口脚本
├── config.sh                      # 配置文件
└── README.md                      # 使用说明
```

## 快速开始

### 1. 上传项目到服务器

```bash
# 解压或上传项目到服务器
cd /path/to/Install_Service

# 设置执行权限
chmod +x install.sh scripts/*.sh lib/*.sh
```

### 2. 初始化目录结构

```bash
./install.sh
# 选择 6. 初始化目录结构
```

### 3. 放置安装包

将安装包放置到对应目录：

**新部署安装包** (`packages/deploy/`)：

| 文件 | 说明 |
|------|------|
| `deploy_basic_suse*.run` | 基础环境包 |
| `deploy_sie_*_mysql_*.run` | SIE 服务 |
| `deploy_vss_*_mysql_*.run` | VSS 服务 |
| `deploy_vim_web_*.run` | VIM_Web 服务 |
| `install-lkdc-*.bin` | LKDC 服务 |
| `install_hy_message_push_server_*.bin` | 消息推送服务 |
| `install_hy_file_server_*.bin` | 文件服务 |
| `sdedb.sql` | 数据库脚本（可选） |
| `nginx.conf` | Nginx 配置（可选） |
| `server.crt`, `server.key`, `root.crt` | 证书文件（可选） |

**升级安装包** (`packages/update/`)：

| 文件 | 说明 |
|------|------|
| `update_sie_*_mysql_*.run` | SIE 升级包 |
| `update_vss_*_mysql_*.run` | VSS 升级包 |
| `install-lkdc-*.bin` | LKDC 升级包 |

> **注意**：升级时 VIM_Web 和证书使用 `packages/deploy/` 目录下的文件

### 4. 执行安装

```bash
# 交互式菜单
./install.sh

# 或直接执行新部署
./install.sh --new

# 或直接执行升级
./install.sh --upgrade
```

## 主菜单

```
╔════════════════════════════════════════════════════════════╗
║         Linux 服务器安装部署服务 v1.0.0               ║
╠════════════════════════════════════════════════════════════╣
║    1. 新部署安装                                         ║
║    2. 升级安装                                           ║
║    3. 检查服务状态                                       ║
║    4. 查看可用安装包                                     ║
║    5. 数据库内外网配置                                   ║
║    6. 初始化目录结构                                     ║
║    0. 退出                                               ║
╚════════════════════════════════════════════════════════════╝
```

## 命令行参数

| 参数 | 说明 |
|------|------|
| `-n, --new` | 执行新部署安装 |
| `-u, --upgrade` | 执行升级安装 |
| `-s, --status` | 检查服务状态 |
| `-l, --list` | 列出可用的安装包 |
| `-h, --help` | 显示帮助信息 |
| `-v, --version` | 显示版本信息 |

## 安装包说明

### 包名匹配规则

- **前缀匹配**：根据包名前缀查找匹配的文件
- **版本排序**：当存在多个版本时，自动选择最新版本
- **时间显示**：查看包时显示文件修改时间，方便确认版本

### 安装参数

| 安装包类型 | 额外参数 |
|-----------|---------| 
| `install-lkdc-*.bin` | `--prefix=/home` |
| `install_hy_message_push_server_*.bin` | `hy` |
| `install_hy_file_server_*.bin` | `hy` |

## 证书和 Nginx 配置

新部署时自动部署以下文件（可选，不影响主流程）：

| 文件 | 目标目录 |
|------|---------|
| `nginx.conf` | `/opt/nginx/conf/` |
| `server.crt`, `server.key` | `/opt/nginx/conf/`、`/home/hy_media_server/bin/` |
| `root.crt` | 上述目录 + `/home/hy_vss_biz_server/conf/` |

同时在 `/opt/nginx/conf/` 创建 `ssl_password_file` 文件。

## 数据库内外网配置

选择菜单 **5. 数据库内外网配置** 可配置：

- 公网/内网 IP 地址
- MTN、PUNCH、SIE、PROXY 等端口
- 自动更新相关数据库表

## 服务检查

安装完成后，脚本会自动检查以下服务状态：

| 服务 | 检查命令 |
|------|---------| 
| SIE | `service sie status` |
| VSS | `service vss status` |
| LKDC | `service lkdc status` |
| Nginx | `service nginxd status` |
| 消息推送 | `service hy_message_push_server status` |
| 文件服务 | `service hy_file_server status` |

## 配置文件

所有配置集中在 `config.sh`：

- 目录路径配置
- MySQL 数据库配置
- Nginx 和证书配置
- 服务列表配置
- 安装顺序配置
- 网络端口默认值

## 注意事项

- ⚠️ 此脚本需要 **root 权限** 运行
- ⚠️ 升级时可选择升级特定服务，无需全部升级
- ⚠️ 升级安装包自带自动备份功能，无需手动备份
- ⚠️ 证书和 nginx.conf 为可选文件，不影响主安装流程

## 日志

安装日志保存在 `logs/` 目录，文件名格式：`install_YYYYMMDD_HHMMSS.log`
