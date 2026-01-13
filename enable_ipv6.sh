#!/bin/bash

#===============================================================================
#
#          FILE:  enable_ipv6.sh
#
#         USAGE:  bash <(curl -fsSL https://raw.githubusercontent.com/你的用户名/ipv6-enabler/main/enable_ipv6.sh)
#
#   DESCRIPTION:  一键启用 VPS IPv6 配置脚本
#                 适用于所有 Linux 发行版
#
#        AUTHOR:  IPv6 Enabler Script
#       VERSION:  1.0.0
#       CREATED:  2026-01-13
#
#===============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 版本号
VERSION="1.0.0"

# 配置文件路径
SYSCTL_CONF="/etc/sysctl.conf"
BACKUP_DIR="/etc/sysctl.conf.backup"

#===============================================================================
# 工具函数
#===============================================================================

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 打印分隔线
print_separator() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要 root 权限运行！"
        print_info "请使用 sudo bash $0 或以 root 用户身份运行"
        exit 1
    fi
}

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        OS_ID=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release)
        OS_ID="rhel"
    elif [ -f /etc/debian_version ]; then
        OS="Debian $(cat /etc/debian_version)"
        OS_ID="debian"
    else
        OS=$(uname -s)
        OS_ID="unknown"
    fi
}

# 检测主网络接口
detect_network_interface() {
    # 尝试多种方法检测主网络接口
    if command -v ip &> /dev/null; then
        MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    fi
    
    if [ -z "$MAIN_INTERFACE" ]; then
        # 备用方法
        MAIN_INTERFACE=$(ls /sys/class/net | grep -v lo | head -1)
    fi
    
    if [ -z "$MAIN_INTERFACE" ]; then
        MAIN_INTERFACE="eth0"
    fi
}

# 获取当前 IPv6 状态
get_ipv6_status() {
    local disabled=0
    
    # 检查 sysctl 配置
    if grep -q "^net.ipv6.conf.all.disable_ipv6.*=.*1" "$SYSCTL_CONF" 2>/dev/null; then
        disabled=1
    fi
    
    if grep -q "^net.ipv6.conf.default.disable_ipv6.*=.*1" "$SYSCTL_CONF" 2>/dev/null; then
        disabled=1
    fi
    
    if grep -q "^net.ipv6.conf.lo.disable_ipv6.*=.*1" "$SYSCTL_CONF" 2>/dev/null; then
        disabled=1
    fi
    
    # 检查实际运行状态
    local runtime_status=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null || echo "1")
    
    if [ "$disabled" -eq 1 ] || [ "$runtime_status" -eq 1 ]; then
        echo "disabled"
    else
        echo "enabled"
    fi
}

# 检测 IPv6 是否已分配
check_ipv6_allocation() {
    echo ""
    print_separator
    echo -e "${WHITE}🔍 检测 IPv6 分配状态${NC}"
    print_separator
    echo ""
    
    detect_network_interface
    local has_ipv6=0
    local ipv6_info=""
    
    # 方法1: 检查全局 IPv6 地址
    print_info "正在检测全局 IPv6 地址..."
    local global_ipv6=$(ip -6 addr show scope global 2>/dev/null | grep inet6 | awk '{print $2}')
    if [ -n "$global_ipv6" ]; then
        has_ipv6=1
        ipv6_info="$global_ipv6"
        echo -e "  ${GREEN}✓${NC} 检测到全局 IPv6 地址:"
        echo "$global_ipv6" | while read addr; do
            echo -e "    ${CYAN}$addr${NC}"
        done
    else
        echo -e "  ${YELLOW}✗${NC} 未检测到全局 IPv6 地址"
    fi
    echo ""
    
    # 方法2: 检查链路本地 IPv6 地址
    print_info "正在检测链路本地 IPv6 地址..."
    local link_local=$(ip -6 addr show scope link 2>/dev/null | grep inet6 | awk '{print $2}')
    if [ -n "$link_local" ]; then
        echo -e "  ${GREEN}✓${NC} 检测到链路本地地址 (fe80::):"
        echo "$link_local" | while read addr; do
            echo -e "    ${CYAN}$addr${NC}"
        done
    else
        echo -e "  ${YELLOW}✗${NC} 未检测到链路本地地址"
    fi
    echo ""
    
    # 方法3: 检查 IPv6 网关
    print_info "正在检测 IPv6 默认网关..."
    local ipv6_gateway=$(ip -6 route show default 2>/dev/null | head -1)
    if [ -n "$ipv6_gateway" ]; then
        has_ipv6=1
        echo -e "  ${GREEN}✓${NC} 检测到 IPv6 网关:"
        echo -e "    ${CYAN}$ipv6_gateway${NC}"
    else
        echo -e "  ${YELLOW}✗${NC} 未检测到 IPv6 默认网关"
    fi
    echo ""
    
    # 方法4: 测试 IPv6 连通性
    print_info "正在测试 IPv6 网络连通性..."
    if command -v ping6 &> /dev/null; then
        if ping6 -c 2 -W 3 2001:4860:4860::8888 &> /dev/null; then
            has_ipv6=1
            echo -e "  ${GREEN}✓${NC} IPv6 网络连通 (可访问 Google DNS)"
        elif ping6 -c 2 -W 3 2400:3200::1 &> /dev/null; then
            has_ipv6=1
            echo -e "  ${GREEN}✓${NC} IPv6 网络连通 (可访问阿里云 DNS)"
        else
            echo -e "  ${YELLOW}✗${NC} IPv6 网络不通"
        fi
    elif command -v ping &> /dev/null; then
        if ping -6 -c 2 -W 3 2001:4860:4860::8888 &> /dev/null; then
            has_ipv6=1
            echo -e "  ${GREEN}✓${NC} IPv6 网络连通 (可访问 Google DNS)"
        elif ping -6 -c 2 -W 3 2400:3200::1 &> /dev/null; then
            has_ipv6=1
            echo -e "  ${GREEN}✓${NC} IPv6 网络连通 (可访问阿里云 DNS)"
        else
            echo -e "  ${YELLOW}✗${NC} IPv6 网络不通"
        fi
    else
        echo -e "  ${YELLOW}!${NC} 无法测试 (ping 命令不可用)"
    fi
    echo ""
    
    # 方法5: 检查网络配置文件
    print_info "正在检查网络配置文件..."
    local config_found=0
    
    # 检查 Debian/Ubuntu 网络配置
    if [ -f /etc/network/interfaces ]; then
        if grep -q "inet6" /etc/network/interfaces 2>/dev/null; then
            config_found=1
            echo -e "  ${GREEN}✓${NC} /etc/network/interfaces 中配置了 IPv6"
        fi
    fi
    
    # 检查 Netplan 配置 (Ubuntu 18.04+)
    if [ -d /etc/netplan ]; then
        if grep -r "addresses:.*:" /etc/netplan/*.yaml 2>/dev/null | grep -v "#" | grep -q ":"; then
            config_found=1
            echo -e "  ${GREEN}✓${NC} Netplan 配置中包含 IPv6 设置"
        fi
    fi
    
    # 检查 CentOS/RHEL 网络脚本
    if [ -d /etc/sysconfig/network-scripts ]; then
        if grep -r "IPV6ADDR" /etc/sysconfig/network-scripts/ifcfg-* 2>/dev/null | grep -v "#" | grep -q "."; then
            config_found=1
            echo -e "  ${GREEN}✓${NC} 网络脚本中配置了 IPv6"
        fi
    fi
    
    # 检查 systemd-networkd 配置
    if [ -d /etc/systemd/network ]; then
        if grep -r "Address=.*:" /etc/systemd/network/*.network 2>/dev/null | grep -v "#" | grep -q ":"; then
            config_found=1
            echo -e "  ${GREEN}✓${NC} systemd-networkd 配置中包含 IPv6"
        fi
    fi
    
    if [ $config_found -eq 0 ]; then
        echo -e "  ${YELLOW}!${NC} 未在常见网络配置文件中检测到 IPv6 配置"
    fi
    echo ""
    
    # 总结诊断结果
    print_separator
    echo -e "${WHITE}📊 诊断结果${NC}"
    print_separator
    echo ""
    
    if [ $has_ipv6 -eq 1 ]; then
        echo -e "${GREEN}✅ 检测到 IPv6 支持！${NC}"
        echo ""
        echo -e "您的 VPS 具备 IPv6 功能，可以继续进行配置。"
        echo -e "如果 IPv6 当前未启用，请选择 ${GREEN}"一键启用 IPv6"${NC} 来开启。"
    else
        echo -e "${RED}⚠️ 未检测到有效的 IPv6 配置${NC}"
        echo ""
        echo -e "可能的原因："
        echo -e "  ${YELLOW}1.${NC} VPS 服务商尚未为您分配 IPv6 地址"
        echo -e "  ${YELLOW}2.${NC} 需要在 VPS 控制面板中申请/启用 IPv6"
        echo -e "  ${YELLOW}3.${NC} IPv6 地址已分配但需要重启网卡或 VPS"
        echo -e "  ${YELLOW}4.${NC} 网络配置文件中缺少 IPv6 配置"
        echo ""
        echo -e "${CYAN}建议操作：${NC}"
        echo -e "  • 登录 VPS 服务商控制面板检查 IPv6 是否已分配"
        echo -e "  • 如已分配，尝试在控制面板重启网卡或重启 VPS"
        echo -e "  • 联系 VPS 服务商客服确认 IPv6 支持情况"
    fi
    echo ""
    print_separator
    
    return $has_ipv6
}

#===============================================================================
# 主要功能函数
#===============================================================================

# 显示欢迎界面
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   ██╗██████╗ ██╗   ██╗ ██████╗     ███████╗███╗   ██╗         ║
    ║   ██║██╔══██╗██║   ██║██╔════╝     ██╔════╝████╗  ██║         ║
    ║   ██║██████╔╝██║   ██║███████╗     █████╗  ██╔██╗ ██║         ║
    ║   ██║██╔═══╝ ╚██╗ ██╔╝██╔═══██╗    ██╔══╝  ██║╚██╗██║         ║
    ║   ██║██║      ╚████╔╝ ╚██████╔╝    ███████╗██║ ╚████║         ║
    ║   ╚═╝╚═╝       ╚═══╝   ╚═════╝     ╚══════╝╚═╝  ╚═══╝         ║
    ║                                                               ║
    ║           VPS IPv6 一键配置脚本 v1.0.0                        ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 显示系统信息
show_system_info() {
    print_separator
    echo -e "${WHITE}系统信息${NC}"
    print_separator
    
    detect_os
    detect_network_interface
    
    echo -e "  ${PURPLE}操作系统:${NC} $OS"
    echo -e "  ${PURPLE}主网卡:${NC} $MAIN_INTERFACE"
    
    local ipv6_status=$(get_ipv6_status)
    if [ "$ipv6_status" == "enabled" ]; then
        echo -e "  ${PURPLE}IPv6 状态:${NC} ${GREEN}已启用${NC}"
    else
        echo -e "  ${PURPLE}IPv6 状态:${NC} ${RED}已禁用${NC}"
    fi
    
    # 显示当前 IPv6 地址（如果有）
    local ipv6_addr=$(ip -6 addr show scope global 2>/dev/null | grep inet6 | awk '{print $2}' | head -1)
    if [ -n "$ipv6_addr" ]; then
        echo -e "  ${PURPLE}IPv6 地址:${NC} ${GREEN}$ipv6_addr${NC}"
    else
        echo -e "  ${PURPLE}IPv6 地址:${NC} ${YELLOW}无${NC}"
    fi
    
    print_separator
}

# 显示主菜单
show_menu() {
    echo ""
    echo -e "${WHITE}请选择操作：${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} 🚀 一键启用 IPv6（推荐）"
    echo -e "  ${GREEN}2.${NC} 🔍 检测 IPv6 分配状态"
    echo -e "  ${GREEN}3.${NC} 🔧 仅修改配置（不重启）"
    echo -e "  ${GREEN}4.${NC} 📋 查看当前 sysctl.conf 配置"
    echo -e "  ${GREEN}5.${NC} 🔄 恢复备份配置"
    echo -e "  ${GREEN}6.${NC} ❌ 禁用 IPv6"
    echo -e "  ${GREEN}0.${NC} 🚪 退出脚本"
    echo ""
    print_separator
}

# 备份配置文件
backup_config() {
    local backup_file="${SYSCTL_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$SYSCTL_CONF" ]; then
        cp "$SYSCTL_CONF" "$backup_file"
        print_success "配置文件已备份到: $backup_file"
        return 0
    else
        print_warning "配置文件不存在，将创建新文件"
        return 1
    fi
}

# 注释掉禁用 IPv6 的行
comment_disable_lines() {
    if [ ! -f "$SYSCTL_CONF" ]; then
        touch "$SYSCTL_CONF"
        return
    fi
    
    # 使用 sed 注释掉禁用 IPv6 的行（如果尚未注释）
    sed -i 's/^net.ipv6.conf.all.disable_ipv6.*=.*1/#&/' "$SYSCTL_CONF"
    sed -i 's/^net.ipv6.conf.default.disable_ipv6.*=.*1/#&/' "$SYSCTL_CONF"
    sed -i 's/^net.ipv6.conf.lo.disable_ipv6.*=.*1/#&/' "$SYSCTL_CONF"
    
    print_success "已注释掉禁用 IPv6 的配置行"
}

# 添加 IPv6 配置
add_ipv6_config() {
    detect_network_interface
    
    local config_marker="# === IPv6 Configuration Added by Script ==="
    local config_end_marker="# === End of IPv6 Configuration ==="
    
    # 检查是否已经添加过配置
    if grep -q "$config_marker" "$SYSCTL_CONF" 2>/dev/null; then
        print_warning "检测到已有脚本添加的 IPv6 配置，将先删除旧配置"
        # 删除旧的配置块
        sed -i "/$config_marker/,/$config_end_marker/d" "$SYSCTL_CONF"
    fi
    
    # 添加新配置
    cat >> "$SYSCTL_CONF" << EOF

$config_marker
# 配置时间: $(date '+%Y-%m-%d %H:%M:%S')
# 主网卡: $MAIN_INTERFACE

# 禁用自动配置和路由通告（使用手动配置的 IPv6）
net.ipv6.conf.all.autoconf = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.$MAIN_INTERFACE.autoconf = 0
net.ipv6.conf.$MAIN_INTERFACE.accept_ra = 0

# 确保 IPv6 已启用
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
$config_end_marker
EOF
    
    print_success "IPv6 配置已添加到 $SYSCTL_CONF"
}

# 应用配置
apply_config() {
    print_info "正在应用 sysctl 配置..."
    
    if sysctl -p 2>/dev/null; then
        print_success "sysctl 配置已生效"
        return 0
    else
        print_error "应用 sysctl 配置时出现问题"
        return 1
    fi
}

# 重启网络服务
restart_network() {
    print_info "正在重启网络服务..."
    
    # 检测并使用适当的网络重启命令
    if command -v systemctl &> /dev/null; then
        # 尝试不同的网络服务名
        if systemctl is-active --quiet networking 2>/dev/null; then
            systemctl restart networking 2>/dev/null && print_success "networking 服务已重启" && return 0
        elif systemctl is-active --quiet NetworkManager 2>/dev/null; then
            systemctl restart NetworkManager 2>/dev/null && print_success "NetworkManager 服务已重启" && return 0
        elif systemctl is-active --quiet network 2>/dev/null; then
            systemctl restart network 2>/dev/null && print_success "network 服务已重启" && return 0
        elif systemctl is-active --quiet systemd-networkd 2>/dev/null; then
            systemctl restart systemd-networkd 2>/dev/null && print_success "systemd-networkd 服务已重启" && return 0
        fi
    fi
    
    # 备用方法
    if [ -f /etc/init.d/networking ]; then
        /etc/init.d/networking restart 2>/dev/null && print_success "网络服务已重启" && return 0
    fi
    
    if [ -f /etc/init.d/network ]; then
        /etc/init.d/network restart 2>/dev/null && print_success "网络服务已重启" && return 0
    fi
    
    print_warning "无法自动重启网络服务，配置将在重启后生效"
    return 1
}

# 询问是否重启系统
ask_reboot() {
    echo ""
    print_warning "为确保 IPv6 配置完全生效，建议重启系统"
    echo ""
    echo -e "  ${GREEN}1.${NC} 立即重启系统"
    echo -e "  ${YELLOW}2.${NC} 稍后手动重启"
    echo ""
    read -p "请选择 [1/2]: " reboot_choice
    
    case $reboot_choice in
        1)
            print_info "系统将在 5 秒后重启..."
            print_info "请在重启后检查 IPv6 是否正常工作"
            sleep 5
            reboot
            ;;
        2)
            print_info "请记得稍后手动执行 'reboot' 命令重启系统"
            ;;
        *)
            print_info "未选择重启，请稍后手动执行 'reboot' 命令"
            ;;
    esac
}

# 一键启用 IPv6
enable_ipv6_full() {
    echo ""
    print_separator
    echo -e "${WHITE}开始一键启用 IPv6${NC}"
    print_separator
    echo ""
    
    # 先检测 IPv6 分配状态
    print_info "正在检测 IPv6 分配状态..."
    echo ""
    
    # 快速检测（不显示详细信息）
    local has_ipv6=0
    local global_ipv6=$(ip -6 addr show scope global 2>/dev/null | grep inet6 | awk '{print $2}' | head -1)
    local ipv6_gateway=$(ip -6 route show default 2>/dev/null | head -1)
    
    if [ -n "$global_ipv6" ]; then
        has_ipv6=1
        echo -e "  ${GREEN}✓${NC} 检测到 IPv6 地址: ${CYAN}$global_ipv6${NC}"
    fi
    
    if [ -n "$ipv6_gateway" ]; then
        has_ipv6=1
        echo -e "  ${GREEN}✓${NC} 检测到 IPv6 网关"
    fi
    
    if [ $has_ipv6 -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠️ 警告：未检测到已分配的 IPv6 地址或网关${NC}"
        echo ""
        echo -e "可能的原因："
        echo -e "  ${YELLOW}•${NC} VPS 服务商尚未分配 IPv6 地址"
        echo -e "  ${YELLOW}•${NC} 需要在 VPS 控制面板申请 IPv6"
        echo -e "  ${YELLOW}•${NC} 已分配但需要重启网卡/VPS 后才能识别"
        echo ""
        echo -e "${CYAN}建议：先选择 "检测 IPv6 分配状态" 进行详细诊断${NC}"
        echo ""
        read -p "是否仍要继续配置？(y/N): " force_continue
        if [ "$force_continue" != "y" ] && [ "$force_continue" != "Y" ]; then
            print_info "已取消操作，建议先完成 IPv6 申请和分配"
            return
        fi
        echo ""
        print_warning "继续配置，但 IPv6 可能在重启后才能正常工作"
    else
        echo -e "  ${GREEN}✓${NC} IPv6 环境检测通过"
    fi
    echo ""
    
    # 步骤 1: 备份
    print_info "步骤 1/4: 备份当前配置..."
    backup_config
    echo ""
    
    # 步骤 2: 注释禁用行
    print_info "步骤 2/4: 注释掉禁用 IPv6 的配置..."
    comment_disable_lines
    echo ""
    
    # 步骤 3: 添加配置
    print_info "步骤 3/4: 添加 IPv6 配置..."
    add_ipv6_config
    echo ""
    
    # 步骤 4: 应用配置
    print_info "步骤 4/4: 应用配置..."
    apply_config
    restart_network
    echo ""
    
    # 验证配置结果
    print_separator
    echo -e "${WHITE}🔍 验证配置结果${NC}"
    print_separator
    echo ""
    
    sleep 2  # 等待网络重启
    
    local new_ipv6=$(ip -6 addr show scope global 2>/dev/null | grep inet6 | awk '{print $2}' | head -1)
    if [ -n "$new_ipv6" ]; then
        echo -e "${GREEN}✅ IPv6 配置成功！${NC}"
        echo -e "  当前 IPv6 地址: ${CYAN}$new_ipv6${NC}"
        
        # 测试连通性
        echo ""
        print_info "测试 IPv6 网络连通性..."
        if ping -6 -c 2 -W 3 2001:4860:4860::8888 &> /dev/null 2>&1 || ping6 -c 2 -W 3 2001:4860:4860::8888 &> /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} IPv6 网络连通正常"
        else
            echo -e "  ${YELLOW}!${NC} IPv6 网络暂时不通，可能需要重启后生效"
        fi
    else
        echo -e "${YELLOW}⚠️ 配置已完成，但尚未检测到 IPv6 地址${NC}"
        echo -e "  这通常是因为："
        echo -e "  ${YELLOW}•${NC} 服务商尚未分配 IPv6 地址"
        echo -e "  ${YELLOW}•${NC} 需要重启系统后才能生效"
        echo -e "  ${YELLOW}•${NC} 需要在控制面板重启网卡"
    fi
    echo ""
    
    print_separator
    echo -e "${GREEN}✅ IPv6 配置操作已完成！${NC}"
    print_separator
    
    # 询问是否重启
    ask_reboot
}

# 仅修改配置（不重启）
modify_config_only() {
    echo ""
    print_separator
    echo -e "${WHITE}修改 IPv6 配置（不重启）${NC}"
    print_separator
    echo ""
    
    backup_config
    comment_disable_lines
    add_ipv6_config
    apply_config
    
    echo ""
    print_separator
    echo -e "${GREEN}✅ 配置已修改！${NC}"
    echo -e "${YELLOW}提示: 部分更改可能需要重启系统后才能完全生效${NC}"
    print_separator
}

# 查看当前配置
view_config() {
    echo ""
    print_separator
    echo -e "${WHITE}当前 sysctl.conf 配置（IPv6 相关）${NC}"
    print_separator
    echo ""
    
    if [ -f "$SYSCTL_CONF" ]; then
        grep -n "ipv6\|IPv6" "$SYSCTL_CONF" 2>/dev/null || echo "未找到 IPv6 相关配置"
    else
        echo "配置文件不存在: $SYSCTL_CONF"
    fi
    
    echo ""
    print_separator
    echo ""
    read -p "按 Enter 键返回主菜单..."
}

# 恢复备份
restore_backup() {
    echo ""
    print_separator
    echo -e "${WHITE}恢复备份配置${NC}"
    print_separator
    echo ""
    
    # 查找备份文件
    local backups=$(ls -t ${SYSCTL_CONF}.backup.* 2>/dev/null)
    
    if [ -z "$backups" ]; then
        print_error "未找到备份文件"
        echo ""
        read -p "按 Enter 键返回主菜单..."
        return
    fi
    
    echo "可用的备份文件："
    echo ""
    
    local i=1
    local backup_array=()
    for backup in $backups; do
        echo -e "  ${GREEN}$i.${NC} $backup"
        backup_array+=("$backup")
        ((i++))
    done
    
    echo ""
    read -p "请选择要恢复的备份编号 (0 取消): " backup_choice
    
    if [ "$backup_choice" == "0" ] || [ -z "$backup_choice" ]; then
        print_info "已取消恢复操作"
        return
    fi
    
    local index=$((backup_choice - 1))
    if [ $index -ge 0 ] && [ $index -lt ${#backup_array[@]} ]; then
        local selected_backup="${backup_array[$index]}"
        cp "$selected_backup" "$SYSCTL_CONF"
        apply_config
        print_success "已恢复备份: $selected_backup"
    else
        print_error "无效的选择"
    fi
    
    echo ""
    read -p "按 Enter 键返回主菜单..."
}

# 禁用 IPv6
disable_ipv6() {
    echo ""
    print_separator
    echo -e "${WHITE}禁用 IPv6${NC}"
    print_separator
    echo ""
    
    print_warning "此操作将禁用系统的 IPv6 功能"
    read -p "确定要继续吗？(y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "已取消操作"
        return
    fi
    
    backup_config
    
    # 移除之前脚本添加的配置
    local config_marker="# === IPv6 Configuration Added by Script ==="
    local config_end_marker="# === End of IPv6 Configuration ==="
    if grep -q "$config_marker" "$SYSCTL_CONF" 2>/dev/null; then
        sed -i "/$config_marker/,/$config_end_marker/d" "$SYSCTL_CONF"
    fi
    
    # 添加禁用 IPv6 的配置
    cat >> "$SYSCTL_CONF" << EOF

# === IPv6 Disabled by Script ===
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
# === End of IPv6 Disabled ===
EOF
    
    apply_config
    
    print_success "IPv6 已禁用"
    echo ""
    ask_reboot
}

#===============================================================================
# 主程序入口
#===============================================================================

main() {
    # 检查 root 权限
    check_root
    
    while true; do
        show_banner
        show_system_info
        show_menu
        
        read -p "请输入选项 [0-6]: " choice
        
        case $choice in
            1)
                enable_ipv6_full
                echo ""
                read -p "按 Enter 键返回主菜单..."
                ;;
            2)
                check_ipv6_allocation
                echo ""
                read -p "按 Enter 键返回主菜单..."
                ;;
            3)
                modify_config_only
                echo ""
                read -p "按 Enter 键返回主菜单..."
                ;;
            4)
                view_config
                ;;
            5)
                restore_backup
                ;;
            6)
                disable_ipv6
                echo ""
                read -p "按 Enter 键返回主菜单..."
                ;;
            0)
                echo ""
                print_info "感谢使用 IPv6 配置脚本！"
                print_info "如有问题，请访问 GitHub 提交 Issue"
                echo ""
                exit 0
                ;;
            *)
                print_error "无效的选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

# 运行主程序
main "$@"
