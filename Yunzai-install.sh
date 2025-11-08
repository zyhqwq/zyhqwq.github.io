#!/bin/bash

# TRSS-Yunzai QQBot官方协议自动安装脚本 (支持 ARM64 和 x64)
# 更新：Redis 8.2.3 + Node.js v24.11.0
# 自动架构检测 + 多版本Chromium支持

set -e

echo "========================================"
echo "  TRSS-Yunzai QQBot官方协议安装脚本"
echo "      (支持 ARM64 和 x64 架构)"
echo "        Redis 8.2.3 + Node.js 24.11.0"
echo "  注意：请在家庭局域网环境使用"
echo "  服务器环境使用可能导致封号！"
echo "========================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测系统架构
detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case $arch in
        "x86_64")
            CURRENT_ARCH="x64"
            NODE_URL="https://nodejs.org/dist/v24.11.0/node-v24.11.0-linux-x64.tar.xz"
            ;;
        "aarch64"|"arm64")
            CURRENT_ARCH="arm64"
            NODE_URL="https://nodejs.org/dist/v24.11.0/node-v24.11.0-linux-arm64.tar.xz"
            ;;
        *)
            log_error "不支持的架构: $arch"
            log_info "支持的架构: x86_64 (x64), aarch64 (arm64)"
            exit 1
            ;;
    esac
    
    log_info "检测到系统架构: $arch, 使用 $CURRENT_ARCH 版本"
}

# 检查系统环境
check_system() {
    detect_architecture
    
    # 检查是否在桌面环境
    if [[ -n "$DISPLAY" ]]; then
        log_warn "检测到图形环境，但脚本将按服务器模式配置"
    fi
    
    # 检查内存
    local total_mem
    total_mem=$(free -g | awk 'NR==2{print $2}')
    if [[ $total_mem -lt 2 ]]; then
        log_warn "系统内存较低（${total_mem}G），建议至少2G内存以顺畅运行"
    fi
}

# 安装基础依赖
install_basic_deps() {
    log_info "更新软件包和安装基础依赖..."
    sudo apt update
    sudo apt install -y wget curl unzip screen git lsb-release build-essential tcl dpkg apt-transport-https
}

# Chromium 安装 (多方法支持)
install_chromium() {
    log_info "开始安装 Chromium (架构: $CURRENT_ARCH)..."
    
    # 方法1: 尝试使用系统包管理器安装
    if install_chromium_apt; then
        log_info "✓ 通过APT安装Chromium成功"
        return 0
    fi
    
    # 方法2: 尝试安装Debian版本
    if install_chromium_debian; then
        log_info "✓ 通过Debian包安装Chromium成功"
        return 0
    fi
    
    # 方法3: 尝试Snap安装
    if install_chromium_snap; then
        log_info "✓ 通过Snap安装Chromium成功"
        return 0
    fi
    
    log_error "所有Chromium安装方法都失败了"
    return 1
}

# 方法1: 使用APT安装Chromium
install_chromium_apt() {
    log_info "尝试通过APT安装Chromium..."
    
    if sudo apt install -y chromium-browser chromium-chromedriver; then
        # 安装无头模式依赖
        sudo apt install -y \
            xvfb \
            libnss3 \
            libxss1 \
            libasound2 \
            libatk-bridge2.0-0 \
            libgtk-3-0 \
            libgbm-dev \
            libxrandr2 \
            libxcomposite1 \
            libxdamage1 \
            libxext6 \
            libxfixes3 \
            libxi6 \
            libxrender1 \
            libxtst6
        return 0
    else
        log_warn "APT安装Chromium失败，尝试其他方法..."
        sudo apt install -f -y
        return 1
    fi
}

# 方法2: 安装Debian版本的Chromium
install_chromium_debian() {
    log_info "尝试安装Debian版本的Chromium..."
    
    local temp_dir
    temp_dir=$(mktemp -d -t chromium-install-XXXXXX)
    cd "$temp_dir"
    
    # 根据架构选择包
    if [[ "$CURRENT_ARCH" == "x64" ]]; then
        local packages=(
            "chromium-codecs-ffmpeg-extra_112.0.5615.49-0ubuntu0.18.04.1_amd64.deb"
            "chromium-browser_112.0.5615.49-0ubuntu0.18.04.1_amd64.deb"
            "chromium-chromedriver_112.0.5615.49-0ubuntu0.18.04.1_amd64.deb"
        )
    else
        local packages=(
            "chromium-codecs-ffmpeg-extra_112.0.5615.49-0ubuntu0.18.04.1_arm64.deb"
            "chromium-browser_112.0.5615.49-0ubuntu0.18.04.1_arm64.deb"
            "chromium-chromedriver_112.0.5615.49-0ubuntu0.18.04.1_arm64.deb"
        )
    fi
    
    local base_url="http://ports.ubuntu.com/pool/universe/c/chromium-browser"
    
    for package in "${packages[@]}"; do
        log_info "下载: $package"
        if ! wget -q --timeout=30 --tries=3 "$base_url/$package"; then
            log_warn "下载 $package 失败"
            rm -rf "$temp_dir"
            return 1
        fi
    done
    
    # 安装包
    for package in "${packages[@]}"; do
        if [[ -f "$package" ]]; then
            sudo dpkg -i "$package" 2>/dev/null || true
        fi
    done
    
    sudo apt install -f -y
    rm -rf "$temp_dir"
    return 0
}

# 方法3: 使用Snap安装Chromium
install_chromium_snap() {
    log_info "尝试通过Snap安装Chromium..."
    
    if ! command -v snap &> /dev/null; then
        log_info "安装snapd..."
        sudo apt install -y snapd
    fi
    
    if sudo snap install chromium; then
        # 创建符号链接以便系统识别
        sudo ln -sf /snap/bin/chromium /usr/local/bin/chromium-browser
        return 0
    else
        log_warn "Snap安装Chromium失败"
        return 1
    fi
}

# 配置 Chromium 服务器优化
configure_chromium_server() {
    log_info "配置 Chromium 服务器优化..."
    
    # 创建无头模式启动脚本
    sudo tee /usr/local/bin/chromium-headless > /dev/null << 'EOF'
#!/bin/bash
# Chromium 无头模式启动脚本 - TRSS-Yunzai 优化版

DEFAULT_ARGS="--headless \
--disable-gpu \
--no-sandbox \
--disable-dev-shm-usage \
--disable-software-rasterizer \
--remote-debugging-port=9222 \
--user-data-dir=/tmp/chromium-profile"

if command -v xvfb-run > /dev/null; then
    exec xvfb-run -a --server-args="-screen 0 1280x1024x24" chromium-browser $DEFAULT_ARGS "$@"
else
    exec chromium-browser $DEFAULT_ARGS "$@"
fi
EOF

    sudo chmod +x /usr/local/bin/chromium-headless
    log_info "创建无头模式启动脚本: /usr/local/bin/chromium-headless"
}

# 验证 Chromium 安装
verify_chromium_installation() {
    log_info "验证 Chromium 安装..."
    
    if command -v chromium-browser &> /dev/null || command -v chromium &> /dev/null; then
        local version
        if command -v chromium-browser &> /dev/null; then
            version=$(chromium-browser --version 2>/dev/null || echo "未知版本")
        else
            version=$(chromium --version 2>/dev/null || echo "未知版本")
        fi
        log_info "✓ Chromium 安装成功: $version"
        
        # 测试无头模式
        log_info "测试无头模式..."
        local test_cmd="chromium-browser"
        if ! command -v chromium-browser &> /dev/null; then
            test_cmd="chromium"
        fi
        
        if timeout 15s $test_cmd --headless --no-sandbox --disable-gpu --dump-dom https://example.com &> /dev/null; then
            log_info "✓ 无头模式测试通过"
        else
            log_warn "⚠ 无头模式测试失败，但安装继续"
        fi
        return 0
    else
        log_error "✗ Chromium 安装失败 - 未找到chromium-browser或chromium命令"
        return 1
    fi
}

# 安装 Redis 8.2.3
install_redis() {
    log_info "安装 Redis 8.2.3..."
    
    cd ~
    log_info "下载 Redis 8.2.3 源码..."
    wget https://download.redis.io/releases/redis-8.2.3.tar.gz
    tar -xf redis-8.2.3.tar.gz
    cd redis-8.2.3
    
    log_info "编译 Redis..."
    make
    sudo make install
    
    # 创建 Redis 配置目录
    sudo mkdir -p /etc/redis
    sudo mkdir -p /var/lib/redis
    
    # 创建 Redis 配置文件
    log_info "创建 Redis 配置文件..."
    sudo tee /etc/redis/redis.conf > /dev/null << EOF
bind 127.0.0.1
port 6379
daemonize no
pidfile /var/run/redis/redis-server.pid
logfile /var/log/redis/redis-server.log
dir /var/lib/redis
EOF
    
    sudo mkdir -p /var/log/redis
    sudo chown redis:redis /var/log/redis
    
    # 创建 Redis 服务文件
    log_info "创建 Redis 系统服务..."
    sudo tee /etc/systemd/system/redis.service > /dev/null << EOF
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
ExecStart=/usr/local/bin/redis-server /etc/redis/redis.conf
ExecStop=/usr/local/bin/redis-cli shutdown
Restart=always
User=redis
Group=redis

[Install]
WantedBy=multi-user.target
EOF

    # 创建 Redis 用户和设置权限
    if ! id "redis" &>/dev/null; then
        sudo useradd -r -s /bin/false redis
    fi
    
    sudo chown -R redis:redis /var/lib/redis
    
    log_info "启动 Redis 服务..."
    sudo systemctl daemon-reload
    sudo systemctl enable redis
    sudo systemctl start redis
    
    log_info "Redis 8.2.3 已安装并启动 (systemd service: redis)"
}

# 安装 Node.js v24.11.0
install_nodejs() {
    log_info "安装 Node.js v24.11.0 (架构: $CURRENT_ARCH)..."
    
    # 检查是否已安装 Node.js
    if command -v node &> /dev/null && node -v | grep -q "v24"; then
        log_info "Node.js 24 已安装"
        return
    fi
    
    cd ~
    log_info "下载 Node.js v24.11.0 Linux $CURRENT_ARCH 版本..."
    wget "$NODE_URL" -O node-v24.11.0-linux-$CURRENT_ARCH.tar.xz
    tar -xf node-v24.11.0-linux-$CURRENT_ARCH.tar.xz
    
    # 移动到系统目录
    sudo mv node-v24.11.0-linux-$CURRENT_ARCH /usr/local/nodejs
    
    # 创建符号链接
    sudo ln -sf /usr/local/nodejs/bin/node /usr/local/bin/node
    sudo ln -sf /usr/local/nodejs/bin/npm /usr/local/bin/npm
    sudo ln -sf /usr/local/nodejs/bin/npx /usr/local/bin/npx
    
    # 配置环境变量
    echo 'export PATH=/usr/local/nodejs/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc
    
    log_info "验证 Node.js 安装..."
    node -v
    npm -v
    
    log_info "配置 npm 淘宝镜像..."
    npm config set registry https://registry.npmmirror.com
    
    log_info "Node.js v24.11.0 ($CURRENT_ARCH) 安装完成"
}

# 安装 TRSS-Yunzai
install_yunzai() {
    log_info "安装 TRSS-Yunzai..."
    
    cd ~
    if [[ -d "Yunzai" ]]; then
        log_info "Yunzai 目录已存在，跳过克隆"
    else
        # 国内镜像
        git clone https://gitee.com/TimeRainStarSky/Yunzai
    fi
    
    cd Yunzai
    
    log_info "安装 pnpm 和依赖..."
    npm i -g pnpm
    pnpm i
    
    log_info "TRSS-Yunzai 安装完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    # 确保 Redis 运行
    if sudo systemctl is-active --quiet redis; then
        log_info "Redis 服务已在运行"
    else
        sudo systemctl start redis
        log_info "Redis 服务已启动"
    fi
    
    # 启动 Yunzai
    cd ~/Yunzai
    if screen -ls | grep -q "yunzai"; then
        log_info "Yunzai 已在运行"
    else
        screen -dmS yunzai node app
        log_info "Yunzai 已启动 (screen session: yunzai)"
    fi
}

# 显示使用说明
show_usage() {
    echo
    echo "========================================"
    echo "        多架构服务器安装完成！"
    echo "       架构: $CURRENT_ARCH"
    echo "       Redis 8.2.3 + Node.js 24.11.0"
    echo "========================================"
    echo
    echo "🎯 服务状态检查:"
    echo "  screen -ls                    # 查看所有服务"
    echo "  screen -r yunzai             # 进入 Yunzai 会话"
    echo "  sudo systemctl status redis  # 检查 Redis 状态"
    echo "  Ctrl+A+D                     # 退出 screen 会话"
    echo
    echo "🔧 版本信息:"
    echo "  架构: $CURRENT_ARCH"
    echo "  Redis: $(redis-server --version 2>/dev/null || echo '8.2.3')"
    echo "  Node.js: $(node -v)"
    echo "  npm: $(npm -v)"
    echo
    echo "📦 Yunzai 插件安装 (在 Yunzai 会话中输入):"
    echo "  #安装QQBot-Plugin           # 安装 QQBot 官方协议插件"
    echo "  #安装genshin                 # 安装原神插件"
    echo "  #安装miao-plugin             # 安装喵喵插件" 
    echo "  #安装TRSS-Plugin             # 安装 TRSS 插件"
    echo
    echo "🤖 QQBot 官方协议配置:"
    echo "  1. 访问 https://q.qq.com/ 创建机器人"
    echo "  2. 获取 AppID, Token, AppSecret"
    echo "  3. 在 Yunzai 中输入: #QQBot设置QQ号:AppID:Token:AppSecret:1:1"
    echo
    echo "🌐 Chromium 支持:"
    echo "  chromium-headless            # 优化无头模式启动"
    echo "  chromium-browser --version   # 验证安装 (如果可用)"
    echo "  chromium --version           # 验证安装 (如果可用)"
    echo
    echo "⚠️  重要提醒:"
    echo "  - 请使用小号测试，避免主号风险"
    echo "  - 仅在家庭局域网环境使用"
    echo "  - 官方协议更稳定，风险较低"
    echo
    echo "🚨 故障排除:"
    echo "  - Chromium 问题: 使用 --no-sandbox 参数"
    echo "  - Redis 问题: sudo systemctl restart redis"
    echo "  - Node.js 问题: 检查 /usr/local/nodejs 权限"
    echo
    echo "========================================"
}

# 主函数
main() {
    log_info "开始 TRSS-Yunzai QQBot官方协议 $CURRENT_ARCH 服务器安装..."
    
    # 检查系统
    check_system
    
    # 安装基础依赖
    install_basic_deps
    
    # 安装 Chromium (多方法)
    if install_chromium; then
        configure_chromium_server
        verify_chromium_installation
    else
        log_warn "Chromium 安装失败，但继续其他组件安装"
    fi
    
    # 安装 Redis 8.2.3
    install_redis
    
    # 安装 Node.js v24.11.0
    install_nodejs
    
    # 安装 TRSS-Yunzai
    install_yunzai
    
    # 启动服务
    start_services
    
    # 显示使用说明
    show_usage
    
    log_info "安装完成！请按照上述说明配置 QQBot 官方协议。"
}

# 执行主函数
main "$@"