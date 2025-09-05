#!/data/data/com.termux/files/usr/bin/sh

# =================================================================
# Termux NAS Unmount Script / Termux NAS 卸载脚本
# =================================================================
# Description: Unmount NAS storage and cleanup resources
# 描述: 卸载 NAS 存储并清理资源
#
# Prerequisites: / 前置条件:
# 1. Rooted Android device with Magisk / 使用 Magisk 的已 root Android 设备
# 2. Previously mounted NAS using start-mount.sh / 之前使用 start-mount.sh 挂载过 NAS
#
# Usage: Run as normal user (script handles root internally)
# 使用方法: 以普通用户身份运行（脚本内部处理 root 权限）
# ./unmount.sh
# =================================================================

# =================================================================
# Configuration Section - Should match your mount script settings
# 配置部分 - 应与挂载脚本设置匹配
# =================================================================

# NAS configuration / NAS 配置
NAS_REMOTE="nas"                    # Rclone remote name / Rclone 远程名称
NAS_PATH="/NAS3T"                   # Remote path on NAS / NAS 上的远程路径
MOUNT_POINT="/sdcard/nas3t"         # Local mount point / 本地挂载点
MOUNT_BASENAME="nas3t"           # Base name for bind mounts / 绑定挂载的基础名称


# =================================================================
# Main Execution
# 主要执行
# =================================================================

echo "Termux NAS Unmount Script"
echo "Termux NAS 卸载脚本"
echo "=========================="
echo ""

# Execute unmount with root privileges
# 以 root 权限执行卸载
echo "Requesting root privileges for unmount operation..."
echo "请求 root 权限进行卸载操作..."
echo ""

su --mount-master -c "/data/data/com.termux/files/usr/bin/sh -s" <<EOF

# Import configuration variables
NAS_REMOTE="$NAS_REMOTE"
NAS_PATH="$NAS_PATH"
MOUNT_POINT="$MOUNT_POINT"
MOUNT_BASENAME="$MOUNT_BASENAME"

# Export PATH to include Termux binaries
export PATH=/data/data/com.termux/files/usr/bin:\$PATH

# =================================================================
# Unmount Function
# 卸载函数
# =================================================================

# Function to perform complete unmount and cleanup
# 执行完整卸载和清理的函数
perform_unmount() {
    echo ""
    echo "=========================================="
    echo "Starting NAS unmount process..."
    echo "开始 NAS 卸载过程..."
    echo "=========================================="
    
    # Get mount basename for bind mount paths / 获取挂载基础名称用于绑定挂载路径

    echo "Target mount point: $MOUNT_POINT base name: $MOUNT_BASENAME"
    echo "目标挂载点: $MOUNT_POINT 基础名称: $MOUNT_BASENAME"
    echo ""
    
    # Check if mount exists before attempting to unmount
    # 在尝试卸载之前检查挂载是否存在
    if ! mount | grep -q "$MOUNT_POINT" && ! mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        echo "WARNING: No active mount found at $MOUNT_POINT"
        echo "警告: 在 $MOUNT_POINT 未找到活动挂载"
        echo "Checking for rclone processes anyway..."
        echo "仍然检查 rclone 进程..."
        echo ""
    else
        echo "Found active mount at $MOUNT_POINT"
        echo "在 $MOUNT_POINT 找到活动挂载"
        echo ""
    fi

    # Step 1: Unmount main FUSE mount
    # 步骤 1: 卸载主 FUSE 挂载
    echo "Step 1: Unmounting main FUSE mount..."
    echo "步骤 1: 卸载主 FUSE 挂载..."

    if fusermount -u -z "$MOUNT_POINT" 2>/dev/null; then
        echo "  ✓ Successfully unmounted FUSE mount at $MOUNT_POINT"
        echo "  ✓ 成功卸载 FUSE 挂载点 $MOUNT_POINT"
    else
        echo "  - FUSE mount not found or already unmounted"
        echo "  - FUSE 挂载未找到或已卸载"
        
        # Try force unmount as fallback
        # 尝试强制卸载作为后备方案
        echo "  Attempting force unmount..."
        echo "  尝试强制卸载..."
        umount -f "$MOUNT_POINT" 2>/dev/null && \
            echo "  ✓ Force unmount successful" || \
            echo "  - Force unmount failed or not needed"
    fi
    echo ""
    
    
    # Step 2: Unmount bind mounts first (Android storage views)
    # 步骤 2: 首先卸载绑定挂载（Android 存储视图）
    echo "Step 2: Unmounting Android storage bind mounts..."
    echo "步骤 2: 卸载 Android 存储绑定挂载..."
    
    umount "/mnt/runtime/read/emulated/0/$MOUNT_BASENAME" 2>/dev/null || true
    sleep 2
    umount "/mnt/runtime/write/emulated/0/$MOUNT_BASENAME" 2>/dev/null || true
    sleep 2
    umount "/mnt/runtime/default/emulated/0/$MOUNT_BASENAME" 2>/dev/null || true
    sleep 2
    
    echo "  Android storage bind mounts processed."
    echo "  Android 存储绑定挂载已处理。"
    echo ""
    

    # Step 3: Terminate rclone processes
    # 步骤 3: 终止 rclone 进程
    echo "Step 3: Terminating rclone processes..."
    echo "步骤 3: 终止 rclone 进程..."
    
    pkill rclone 2>/dev/null && \
        echo "  ✓ rclone processes terminated" || \
        echo "  - No rclone processes found"
    echo ""
    
    # Step 4: Clean up mount directory (optional)
    # 步骤 4: 清理挂载目录（可选）
    echo "Step 4: Cleaning up mount directory..."
    echo "步骤 4: 清理挂载目录..."
    
    if [ -d "$MOUNT_POINT" ]; then
        # Check if directory is empty
        # 检查目录是否为空
        if [ -z "$(ls -A "$MOUNT_POINT" 2>/dev/null)" ]; then
            echo "  Mount directory is empty, keeping it for future use"
            echo "  挂载目录为空，保留以供将来使用"
        else
            echo "  Mount directory not empty, leaving as-is"
            echo "  挂载目录不为空，保持原样"
        fi
        
        # Reset permissions to default
        # 重置权限为默认值
        chmod 755 "$MOUNT_POINT" 2>/dev/null || true
        echo "  ✓ Reset directory permissions"
        echo "  ✓ 重置目录权限"
    else
        echo "  - Mount directory not found"
        echo "  - 挂载目录未找到"
    fi
    echo ""
    
    # Step 5: Release wake lock if script is keeping Termux awake
    # 步骤 5: 如果脚本保持 Termux 唤醒则释放唤醒锁
    echo "Step 5: Releasing wake lock..."
    echo "步骤 5: 释放唤醒锁..."
    
    if command -v termux-wake-unlock >/dev/null 2>&1; then
        termux-wake-unlock 2>/dev/null && \
            echo "  ✓ Wake lock released" || \
            echo "  - No wake lock to release"
    else
        echo "  - termux-wake-unlock not available"
        echo "  - termux-wake-unlock 不可用"
    fi
    echo ""
    
    echo "=========================================="
    echo "Unmount process completed!"
    echo "卸载过程完成！"
    echo "=========================================="
    echo ""
}

# =================================================================
# Verification Function
# 验证函数
# =================================================================

# Function to verify unmount was successful
# 验证卸载是否成功的函数
verify_unmount() {
    echo "Verifying unmount status..."
    echo "验证卸载状态..."
    echo ""
    
    # Check mount status
    # 检查挂载状态
    if mount | grep -q "$MOUNT_POINT"; then
        echo "⚠ WARNING: Mount still appears in mount table"
        echo "⚠ 警告: 挂载仍出现在挂载表中"
        mount | grep "$MOUNT_POINT"
        echo ""
        return 1
    else
        echo "✓ No mount found in mount table"
        echo "✓ 挂载表中未找到挂载"
    fi
    
    # Check mountpoint command
    # 检查 mountpoint 命令
    if command -v mountpoint >/dev/null 2>&1; then
        if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
            echo "⚠ WARNING: mountpoint command still reports mount as active"
            echo "⚠ 警告: mountpoint 命令仍报告挂载为活动状态"
            return 1
        else
            echo "✓ mountpoint command confirms no active mount"
            echo "✓ mountpoint 命令确认没有活动挂载"
        fi
    fi
    
    # Check rclone processes
    # 检查 rclone 进程
    RCLONE_COUNT=$(ps | grep rclone | grep -v grep | wc -l | tr -d ' \t\n')
    # Ensure we have a valid number, default to 0 if empty
    RCLONE_COUNT=${RCLONE_COUNT:-0}
    if [ "$RCLONE_COUNT" -gt 0 ]; then
        echo "⚠ WARNING: $RCLONE_COUNT rclone process(es) still running"
        echo "⚠ 警告: $RCLONE_COUNT 个 rclone 进程仍在运行"
        ps | grep rclone | grep -v grep
        return 1
    else
        echo "✓ No rclone processes running"
        echo "✓ 没有 rclone 进程在运行"
    fi
    
    echo ""
    echo "✅ Unmount verification successful!"
    echo "✅ 卸载验证成功！"
    echo ""
    return 0
}


# Execute unmount
perform_unmount

# Verify unmount was successful
if verify_unmount; then
    echo "🎉 NAS unmount completed successfully!"
    echo "🎉 NAS 卸载成功完成！"
    exit 0
else
    echo "❌ Unmount verification failed - some resources may still be active"
    echo "❌ 卸载验证失败 - 一些资源可能仍处于活动状态"
    echo ""
    echo "You may need to:"
    echo "您可能需要："
    echo "  1. Reboot the device / 重启设备"
    echo "  2. Manually kill remaining processes / 手动杀死剩余进程"
    echo "  3. Check for apps still using the mount / 检查是否有应用仍在使用挂载"
    exit 1
fi

EOF

echo ""
echo "Unmount script execution completed."
echo "卸载脚本执行完成。"
