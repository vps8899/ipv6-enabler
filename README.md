# 🌐 VPS IPv6 一键启用脚本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org/)

一款专为 VPS 用户设计的 **IPv6 自动配置脚本**，适用于所有主流 Linux 发行版。

## ✨ 功能特点

- 🚀 **一键启用** - 自动完成所有配置步骤
- 🎨 **交互式界面** - 彩色菜单，操作简单直观
- 🔒 **安全备份** - 自动备份配置文件，支持一键恢复
- 🖥️ **全平台支持** - 支持 Ubuntu、Debian、CentOS、RHEL、Fedora、Alpine 等所有主流发行版
- 🔧 **智能检测** - 自动检测网卡名称和系统类型
- ⚡ **快速部署** - 一条命令即可运行

## 📋 适用场景

当您的 VPS 系统默认禁用了 IPv6，但您已向服务商申请到了 IPv6 地址时，可以使用此脚本快速启用 IPv6。

脚本会自动：
1. 注释掉 `/etc/sysctl.conf` 中禁用 IPv6 的配置
2. 添加正确的 IPv6 配置参数
3. 应用配置并重启网络服务

## 🚀 快速开始

### 方式一：在线运行（推荐）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vps8899/ipv6-enabler/main/enable_ipv6.sh)
```

或使用 wget：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/vps8899/ipv6-enabler/main/enable_ipv6.sh)
```

### 方式二：下载后运行

```bash
# 下载脚本
wget https://raw.githubusercontent.com/vps8899/ipv6-enabler/main/enable_ipv6.sh

# 添加执行权限
chmod +x enable_ipv6.sh

# 运行脚本
sudo ./enable_ipv6.sh
```

## 📖 使用说明

运行脚本后，您将看到一个交互式菜单：

```
╔═══════════════════════════════════════════════════════════════╗
║           VPS IPv6 一键配置脚本 v1.0.0                        ║
╚═══════════════════════════════════════════════════════════════╝

请选择操作：

  1. 🚀 一键启用 IPv6（推荐）
  2. 🔧 仅修改配置（不重启）
  3. 📋 查看当前 sysctl.conf 配置
  4. 🔄 恢复备份配置
  5. ❌ 禁用 IPv6
  0. 🚪 退出脚本
```

### 选项说明

| 选项 | 功能 | 说明 |
|------|------|------|
| 1 | 一键启用 IPv6 | 完整执行所有步骤，包括备份、修改配置、应用更改，并询问是否重启 |
| 2 | 仅修改配置 | 只修改配置文件，不重启系统（适合需要手动控制重启时机的用户） |
| 3 | 查看配置 | 显示当前 sysctl.conf 中与 IPv6 相关的配置 |
| 4 | 恢复备份 | 从之前的备份中恢复配置 |
| 5 | 禁用 IPv6 | 如需禁用 IPv6，可使用此选项 |
| 0 | 退出 | 退出脚本 |

## 🔧 脚本原理

脚本会对 `/etc/sysctl.conf` 进行以下修改：

### 1. 注释掉禁用 IPv6 的行

```bash
# 原配置（被注释）
#net.ipv6.conf.all.disable_ipv6 = 1
#net.ipv6.conf.default.disable_ipv6 = 1
#net.ipv6.conf.lo.disable_ipv6 = 1
```

### 2. 添加 IPv6 配置

```bash
# === IPv6 Configuration Added by Script ===
net.ipv6.conf.all.autoconf = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.eth0.autoconf = 0
net.ipv6.conf.eth0.accept_ra = 0
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
# === End of IPv6 Configuration ===
```

> 注：`eth0` 会自动替换为您系统检测到的实际网卡名称

### 3. 应用配置

```bash
sysctl -p
systemctl restart networking
```

## ⚠️ 注意事项

1. **需要 root 权限** - 脚本需要以 root 用户或使用 sudo 运行
2. **需要先申请 IPv6** - 请确保已向 VPS 服务商申请并分配了 IPv6 地址
3. **重启生效** - 部分更改可能需要重启系统后才能完全生效
4. **备份配置** - 脚本会自动备份，但建议您手动记录原始配置

## 🖥️ 支持的系统

- ✅ Ubuntu 16.04+
- ✅ Debian 8+
- ✅ CentOS 7+
- ✅ RHEL 7+
- ✅ Fedora 30+
- ✅ Alpine Linux
- ✅ Arch Linux
- ✅ openSUSE
- ✅ 其他使用 systemd 或 sysvinit 的 Linux 发行版

## 🐛 常见问题

### Q: 运行后 IPv6 仍然不工作？

A: 请确认：
1. VPS 服务商已为您分配了 IPv6 地址
2. 已正确配置 IPv6 网关
3. 尝试完全重启系统

### Q: 如何手动配置 IPv6 地址？

A: 配置 IPv6 地址需要编辑网络配置文件，具体方法因系统而异：
- Ubuntu/Debian: `/etc/network/interfaces` 或 Netplan
- CentOS/RHEL: `/etc/sysconfig/network-scripts/`
- 使用 NetworkManager 的系统: `nmcli` 或 `nmtui`

### Q: 如何检查 IPv6 是否正常工作？

A: 运行以下命令：
```bash
# 查看 IPv6 地址
ip -6 addr show

# 测试 IPv6 连接
ping6 google.com

# 或
curl -6 https://ipv6.google.com
```

## 📜 更新日志

### v1.0.0 (2026-01-13)
- 🎉 首次发布
- ✨ 支持一键启用/禁用 IPv6
- ✨ 自动检测网卡和系统类型
- ✨ 配置备份与恢复功能
- ✨ 交互式彩色菜单

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

如果觉得这个脚本对您有帮助，请给个 ⭐ Star 支持一下！

