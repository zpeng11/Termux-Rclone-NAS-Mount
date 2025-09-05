#!/data/data/com.termux/files/usr/bin/sh

# =================================================================
# Termux NAS Mount Script / Termux NAS 挂载脚本
# =================================================================
# Description: Mount NAS storage using rclone with FUSE in Termux
# 描述: 在 Termux 中使用 rclone 和 FUSE 挂载 NAS 存储
#
# Prerequisites: / 前置条件:
# 1. Rooted Android device with Magisk / 使用 Magisk 的已 root Android 设备
# 2. Install root-repo in Termux / 在 Termux 中安装 root-repo
# 3. Install packages: libfuse2/3, mount-utils, rclone / 安装软件包: libfuse2/3, mount-utils, rclone
# 4. Configure rclone with your NAS settings / 配置 rclone 连接到您的 NAS
#
# Usage: Run with root privileges / 使用方法直接运行脚本
# /path/to/start-mount.sh
# =================================================================

# =================================================================
# Configuration Section - Modify these variables as needed
# 配置部分 - 根据需要修改这些变量
# =================================================================

# NAS configuration / NAS 配置
NAS_REMOTE="nas"                    # Rclone remote name / Rclone 远程名称
NAS_PATH="/NAS3T"                   # Remote path on NAS / NAS 上的远程路径
MOUNT_POINT="/sdcard/nas3t"         # Local mount point / 本地挂载点
MOUNT_BASENAME="nas3t"           # Base name for bind mounts / 绑定挂载的基础名称

# Cache configuration / 缓存配置
CACHE_DIR="/data/data/com.termux/files/home/.cache"    # Cache directory / 缓存目录
DIR_CACHE_TIME="72h"                                   # Directory cache time / 目录缓存时间

# Permissions / 权限设置
MOUNT_GID="9997"                    # Group ID (sdcard_rw) / 组 ID (sdcard_rw)
DIR_PERMS="0777"                    # Directory permissions / 目录权限
FILE_PERMS="0660"                   # File permissions / 文件权限

# Timing / 时间设置
INIT_WAIT_TIME="5"                 # Initial wait time / 初始等待时间
MOUNT_WAIT_TIME="2"                 # Wait time after mount / 挂载后等待时间
VERIFICATION_TIMEOUT="30"           # Mount verification timeout / 挂载验证超时时间

# =================================================================
# Graceful Shutdown Handling
# 优雅关闭处理
# =================================================================

# Function to cleanup resources on interruption/failure only
# 仅在中断/失败时清理资源的函数
cleanup() {
    echo ""
    echo "=========================================="
    echo "Cleaning up resources due to interruption..."
    echo "由于中断正在清理资源..."
    echo "=========================================="
    
    # Unmount bind mounts first / 首先卸载绑定挂载
    echo "Unmounting bind mounts..."
    echo "卸载绑定挂载..."
    umount /mnt/runtime/default/emulated/0/nas3t 2>/dev/null || true
    umount /mnt/runtime/read/emulated/0/nas3t 2>/dev/null || true
    umount /mnt/runtime/write/emulated/0/nas3t 2>/dev/null || true
    
    # Unmount main FUSE mount / 卸载主 FUSE 挂载
    echo "Unmounting FUSE mount..."
    echo "卸载 FUSE 挂载..."
    fusermount -u -z "$MOUNT_POINT" 2>/dev/null || true
    
    # Kill rclone processes / 杀死 rclone 进程
    echo "Terminating rclone processes..."
    echo "终止 rclone 进程..."
    pkill -TERM rclone 2>/dev/null || true
    sleep 2
    pkill -KILL rclone 2>/dev/null || true
    
    Release wake lock / 释放唤醒锁
    echo "Releasing wake lock..."
    echo "释放唤醒锁..."
    termux-wake-unlock 2>/dev/null || true
    
    echo "Cleanup completed."
    echo "清理完成。"
    exit 1
}

# Function for successful exit without cleanup
# 成功退出时不进行清理的函数
successful_exit() {
    echo ""
    echo "=========================================="
    echo "Mount completed successfully - keeping processes running"
    echo "挂载成功完成 - 保持进程运行"
    echo "=========================================="
    echo "To manually unmount later, run:"
    echo "要稍后手动卸载，请运行："
    echo "  tsu"
    echo "  fusermount -u -z $MOUNT_POINT"
    echo "  umount /mnt/runtime/default/emulated/0/$(basename "$MOUNT_POINT")"
    echo "  pkill rclone"
    echo "=========================================="
}

# Set up signal handlers for interruption only (not normal exit)
# 仅为中断设置信号处理程序（不包括正常退出）
trap cleanup INT TERM QUIT

# Keep Termux awake to prevent the script from being killed
# 保持 Termux 唤醒，防止脚本被系统杀死
termux-wake-lock

# Wait for system initialization to complete
# 等待系统初始化完成
sleep "$INIT_WAIT_TIME"

# Execute commands with root privileges and mount namespace access
# 以 root 权限和挂载命名空间访问权限执行命令
su --mount-master -c "/data/data/com.termux/files/usr/bin/sh -s" <<EOF

# Pass configuration variables to the sub-shell
# 将配置变量传递给子 shell
NAS_REMOTE="$NAS_REMOTE"
NAS_PATH="$NAS_PATH" 
MOUNT_POINT="$MOUNT_POINT"
CACHE_DIR="$CACHE_DIR"
DIR_CACHE_TIME="$DIR_CACHE_TIME"
MOUNT_GID="$MOUNT_GID"
DIR_PERMS="$DIR_PERMS"
FILE_PERMS="$FILE_PERMS"
MOUNT_WAIT_TIME="$MOUNT_WAIT_TIME"
VERIFICATION_TIMEOUT="$VERIFICATION_TIMEOUT"
MOUNT_BASENAME="$MOUNT_BASENAME"

# Exit immediately if any command fails (strict error handling)
# 如果任何命令失败则立即退出（严格错误处理）
set -e

# Temporarily disable SELinux to allow FUSE mounts (ignore errors if already disabled)
# 临时禁用 SELinux 以允许 FUSE 挂载（如果已禁用则忽略错误）
setenforce 0 || true

# Export PATH to include Termux binaries (append to existing PATH to avoid overwriting)
# 导出 PATH 以包含 Termux 二进制文件（追加到现有 PATH，避免覆盖）
export PATH=/data/data/com.termux/files/usr/bin:$PATH

# Export rclone configuration file location
# 导出 rclone 配置文件位置
export RCLONE_CONFIG=/data/data/com.termux/files/home/.config/rclone/rclone.conf

# =================================================================
# Cleanup Section - Remove old mounts and processes
# 清理部分 - 移除旧的挂载和进程
# =================================================================

# Force unmount old mount (lazy unmount, ignore errors if not mounted)
# 强制卸载旧挂载（懒卸载，如果未挂载则忽略错误）
fusermount -u -z "\$MOUNT_POINT" || true

# Kill any remaining rclone processes to prevent conflicts
# 杀死残留的 rclone 进程以防止冲突
pkill -9 rclone || true

# =================================================================
# Directory Setup - Create mount points and set permissions
# 目录设置 - 创建挂载点并设置权限
# =================================================================

# Create the primary mount point if it doesn't exist
# 创建主挂载点（如果不存在）
mkdir -p "\$MOUNT_POINT"

# Create directories for bind mount target views (Android storage access framework)
# 为绑定挂载目标视图创建目录（Android 存储访问框架）
# These paths allow apps to access the mounted storage through different permission contexts
# 这些路径允许应用通过不同的权限上下文访问挂载的存储
mkdir -p "/mnt/runtime/default/emulated/0/\$MOUNT_BASENAME" || true  # Default app access / 默认应用访问
mkdir -p "/mnt/runtime/read/emulated/0/\$MOUNT_BASENAME" || true     # Read-only access / 只读访问
mkdir -p "/mnt/runtime/write/emulated/0/\$MOUNT_BASENAME" || true    # Read-write access / 读写访问

# Set proper ownership and permissions for Android app compatibility
# 设置适当的所有权和权限以兼容 Android 应用
# media_rw group (GID 1023) allows media apps to access the storage
# media_rw 组（GID 1023）允许媒体应用访问存储
chown -R media_rw:media_rw "\$MOUNT_POINT" || true
chmod -R "\$DIR_PERMS" "\$MOUNT_POINT" || true

# =================================================================
# Rclone Mount Section - Mount NAS storage using FUSE
# Rclone 挂载部分 - 使用 FUSE 挂载 NAS 存储
# =================================================================

echo "Starting rclone mount process..."
echo "开始 rclone 挂载过程..."

# Execute rclone mount in daemon mode (background process)
# 以守护进程模式执行 rclone 挂载（后台进程）
# Parameters explanation / 参数说明:
# --allow-other: Allow other users/apps to access the mount / 允许其他用户/应用访问挂载
# --gid: Set group ID to sdcard_rw for Android compatibility / 设置组 ID 为 sdcard_rw 以兼容 Android
# --dir-perms: Set directory permissions to full access / 设置目录权限为完全访问
# --file-perms: Set file permissions (rw-rw----) / 设置文件权限（rw-rw----）
# --umask=0: Don't mask any permissions / 不屏蔽任何权限
# --vfs-cache-mode full: Enable full VFS caching for better performance / 启用完整 VFS 缓存以获得更好性能
# --dir-cache-time: Cache directory listings / 缓存目录列表
# --cache-dir: Specify cache directory location / 指定缓存目录位置
# --daemon: Run in background / 在后台运行
rclone mount "\$NAS_REMOTE:\$NAS_PATH" "\$MOUNT_POINT" \\
    --allow-other \\
    --gid "\$MOUNT_GID" \\
    --dir-perms "\$DIR_PERMS" \\
    --file-perms "\$FILE_PERMS" \\
    --umask=0 \\
    --vfs-cache-mode full \\
    --dir-cache-time "\$DIR_CACHE_TIME" \\
    --cache-dir "\$CACHE_DIR" \\
    --daemon

echo "Rclone mount command executed"
echo "Rclone 挂载命令已执行"

# Wait for mount to stabilize before proceeding (prevent race conditions)
# 等待挂载稳定后再继续（防止竞争条件）
sleep "\$MOUNT_WAIT_TIME"

# =================================================================
# Mount Verification Section - Verify the mount was successful
# 挂载验证部分 - 验证挂载是否成功
# =================================================================

echo "Verifying mount..."
echo "验证挂载..."

# Function to check if mount point is properly mounted
# 检查挂载点是否正确挂载的函数
verify_mount() {
    local timeout="\$1"
    local count=0
    
    while [ \$count -lt \$timeout ]; do
        # Check if mountpoint command is available and mount point is mounted
        # 检查 mountpoint 命令是否可用以及挂载点是否已挂载
        if command -v mountpoint >/dev/null 2>&1; then
            if mountpoint -q "\$MOUNT_POINT"; then
                echo "Mount verification successful using mountpoint command"
                echo "使用 mountpoint 命令验证挂载成功"
                return 0
            fi
        else
            # Fallback: check if mount point appears in /proc/mounts
            # 回退方案：检查挂载点是否出现在 /proc/mounts 中
            if grep -q "\$MOUNT_POINT" /proc/mounts; then
                echo "Mount verification successful using /proc/mounts"
                echo "使用 /proc/mounts 验证挂载成功"
                return 0
            fi
        fi
        
        # Additional check: try to access the mount point
        # 额外检查：尝试访问挂载点
        if [ -d "\$MOUNT_POINT" ] && ls "\$MOUNT_POINT" >/dev/null 2>&1; then
            echo "Mount verification successful - directory accessible"
            echo "挂载验证成功 - 目录可访问"
            return 0
        fi
        
        count=\$((count + 1))
        echo "Mount verification attempt \$count/\$timeout..."
        echo "挂载验证尝试 \$count/\$timeout..."
        sleep 1
    done
    
    return 1
}

# Perform mount verification with timeout
# 执行带超时的挂载验证
if ! verify_mount "\$VERIFICATION_TIMEOUT"; then
    echo "ERROR: Mount verification failed after \$VERIFICATION_TIMEOUT seconds!"
    echo "错误：挂载验证在 \$VERIFICATION_TIMEOUT 秒后失败！"
    echo "Please check:"
    echo "请检查："
    echo "  1. Rclone configuration: rclone config show \$NAS_REMOTE"
    echo "  1. Rclone 配置: rclone config show \$NAS_REMOTE"
    echo "  2. Network connectivity to NAS"
    echo "  2. 到 NAS 的网络连接"
    echo "  3. Rclone processes: ps | grep rclone"
    echo "  3. Rclone 进程: ps | grep rclone"
    exit 1
fi

# =================================================================
# Bind Mount Section - Make storage accessible to Android apps
# 绑定挂载部分 - 使存储可供 Android 应用访问
# =================================================================

echo "Creating bind mounts for Android app compatibility..."
echo "为 Android 应用兼容性创建绑定挂载..."

# Execute bind mounts to multiple Android storage views
# 执行绑定挂载到多个 Android 存储视图
# These bind mounts make the NAS storage visible to Android apps through the storage access framework
# 这些绑定挂载使 NAS 存储通过存储访问框架对 Android 应用可见

# Bind to read-write runtime view (for apps with full storage permission)
# 绑定到读写运行时视图（适用于具有完整存储权限的应用）
mount --bind "\$MOUNT_POINT" "/mnt/runtime/write/emulated/0/\$MOUNT_BASENAME" || true

# =================================================================
# Completion and Status Output
# 完成和状态输出
# =================================================================

echo "=========================================="
echo "Mount process completed successfully!"
echo "挂载过程成功完成！"
echo "=========================================="
echo "NAS storage is now accessible at:"
echo "NAS 存储现在可以在以下位置访问："
echo "  - \$MOUNT_POINT (primary mount point)"
echo "  - \$MOUNT_POINT (主挂载点)"
echo ""
echo "Configuration used:"
echo "使用的配置："
echo "  - Remote: \$NAS_REMOTE:\$NAS_PATH"
echo "  - 远程: \$NAS_REMOTE:\$NAS_PATH"
echo "  - Cache: \$CACHE_DIR"
echo "  - 缓存: \$CACHE_DIR"
echo "  - Permissions: dirs=\$DIR_PERMS, files=\$FILE_PERMS"
echo "  - 权限: 目录=\$DIR_PERMS, 文件=\$FILE_PERMS"
echo ""
echo "For troubleshooting, check:"
echo "故障排除时，请检查："
echo "  - Mount status: mount | grep \$MOUNT_BASENAME"
echo "  - 挂载状态: mount | grep \$MOUNT_BASENAME"
echo "  - Rclone processes: ps | grep rclone"
echo "  - Rclone 进程: ps | grep rclone"
echo "=========================================="


EOF

# Call successful exit function to show completion message
# 调用成功退出函数显示完成消息
successful_exit
