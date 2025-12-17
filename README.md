# Linux 服务器安装部署服务

一键部署和升级 Linux 服务器上的多个服务模块（SIE、VSS、LKDC、VIM_Web、消息推送、文件服务）。

## 功能特性

- ✅ 支持新部署和升级两种安装模式
- ✅ 自动匹配最新版本的安装包（基于版本号或修改时间）
- ✅ 交互式菜单和命令行参数两种使用方式
- ✅ 安装完成后自动检查服务状态
- ✅ 彩色日志输出，便于查看安装进度

## 目录结构

```
Install_Service/
├── packages/                      # 安装包目录
│   ├── deploy/                    # 新部署安装包
│   └── update/                    # 升级安装包
├── lib/
│   ├── package_matcher.sh         # 包名模糊匹配模块
│   ├── service_checker.sh         # 服务状态检查模块
│   └── common.sh                  # 公共函数库
├── scripts/
│   ├── deploy_new.sh              # 新部署脚本
│   └── deploy_upgrade.sh          # 升级安装脚本
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
# 选择 5. 初始化目录结构
```

### 3. 放置安装包

将安装包放置到对应目录：

**新部署安装包** (`packages/deploy/`)：
- `deploy_basic_suse*.run`
- `deploy_sie_*_mysql_*.run`
- `deploy_vss_*_mysql_*.run`
- `deploy_vim_web_*.run`
- `install-lkdc-*.bin`
- `install_hy_message_push_server_*.bin`
- `install_hy_file_server_*.bin`
- `sdedb.sql` - 数据库脚本（安装完成后自动导入）

**升级安装包** (`packages/update/`)：
- `update_sie_*_mysql_*.run`
- `update_vss_*_mysql_*.run`
- `install-lkdc-*.bin`

> **注意**：升级时 VIM_Web 使用 `packages/deploy/` 目录下的 `deploy_vim_web_*.run`（新旧部署共用同一个包）

### 4. 执行安装

```bash
# 交互式菜单
./install.sh

# 或直接执行新部署
./install.sh --new

# 或直接执行升级
./install.sh --upgrade
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

由于安装包文件名包含版本号，脚本使用模糊匹配来查找安装包：

1. **前缀匹配**：根据包名前缀查找匹配的文件
2. **版本排序**：当存在多个版本时，自动选择最新版本
3. **时间兜底**：如果版本号无法解析，使用文件修改时间排序

### 安装参数

| 安装包类型 | 额外参数 |
|-----------|---------|
| `install-lkdc-*.bin` | `--prefix=/home` |
| `install_hy_message_push_server_*.bin` | `hy` |
| `install_hy_file_server_*.bin` | `hy` |

## 服务检查

安装完成后，脚本会自动检查以下服务状态：

| 服务 | 检查命令 |
|------|---------|
| SIE | `service sie status` |
| VSS | `service vss status` |
| LKDC | `service lkdc status` |
| 消息推送 | `service hy_message_push_server status` |
| 文件服务 | `service hy_file_server status` |

## 数据库导入

新部署安装完成后，脚本会自动导入数据库脚本：

- **脚本文件**：`packages/deploy/sdedb.sql`
- **目标数据库**：`sdedb`
- **导入后操作**：自动重启 SIE 和 VSS 服务

> **注意**：数据库密码配置在 `config.sh` 中的 `MYSQL_PASSWORD` 变量

## 注意事项

- ⚠️ 此脚本需要 **root 权限** 运行
- ⚠️ 升级安装包自带自动备份功能，无需手动备份
- ⚠️ `install` 系列安装包可能需要交互操作（如确认覆盖），请注意屏幕提示

## 配置修改

如需修改安装参数，请编辑 `config.sh` 文件：

```bash
# LKDC 安装前缀
LKDC_PREFIX="/home"

# 消息推送和文件服务安装参数
HY_SERVICE_PARAM="hy"
```

## 日志

安装日志保存在 `logs/` 目录，文件名格式：`install_YYYYMMDD_HHMMSS.log`
