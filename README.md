# Termux NAS Mount Script

A robust script for mounting NAS storage in Termux using rclone with FUSE, making network storage accessible to Android apps. I have only tested on my Android8.1 MiPad4. Higher version Android may need changes to steps accordingly but ideas are the same.

## 🌟 Features

- **🔄 Automatic Mount**: Mount NAS storage using rclone with optimal Android compatibility settings
- **📱 Android App Integration**: Creates bind mounts for Android Storage Access Framework
- **🛡️ Robust Error Handling**: Mount verification, graceful shutdown, and comprehensive cleanup
- **⚙️ Highly Configurable**: Easy configuration through variables at the top of the script
- **🔄 Retry Logic**: Built-in retry mechanisms for network connectivity issues
- **📝 Bilingual Support**: Comments in both English and Chinese

## 📋 Prerequisites

### Hardware/Software Requirements
- **Rooted Android device** with Magisk installed, and enable global-naming-space mode in settings.
- **Termux** app installed from F-Droid (recommended) or GitHub releases
- **Network connectivity** to your NAS device

### Required Termux Packages
```bash
# Enable root repository
pkg install root-repo

# Install required packages
pkg install libfuse2 libfuse3 mount-utils rclone
```

### Rclone Configuration
Configure rclone to connect to your NAS under normal user:
```bash
rclone config
```

Follow the interactive setup to create a remote configuration (e.g., named "nas").

## 🚀 Installation

1. **Clone or download the script**:
   ```bash
   git clone https://github.com/your-username/Termux-Rclone-NAS-Mount.git
   cd Termux-Rclone-NAS-Mount
   ```

2. **Make the script executable**:
   ```bash
   chmod +x mount.sh
   ```

3. **Configure the script** by editing the variables at the top of `mount.sh`:
   ```bash
   nano mount.sh
   ```

## ⚙️ Configuration

Edit these variables at the top of the script according to your setup:

```bash
# NAS configuration
NAS_REMOTE="nas"                    # Rclone remote name
NAS_PATH="/NAS3T"                   # Remote path on NAS
MOUNT_POINT="/sdcard/nas3t"         # Local mount point
MOUNT_BASENAME="nas3t"              # Base name for bind mounts

# Cache configuration
CACHE_DIR="/data/data/com.termux/files/home/.cache"    # Cache directory
DIR_CACHE_TIME="72h"                                   # Directory cache time

# Permissions
MOUNT_GID="9997"                    # Group ID (sdcard_rw)
DIR_PERMS="0777"                    # Directory permissions
FILE_PERMS="0660"                   # File permissions

# Timing
INIT_WAIT_TIME="5"                 # Initial wait time
MOUNT_WAIT_TIME="2"                 # Wait time after mount
VERIFICATION_TIMEOUT="30"           # Mount verification timeout
```

## 🏃‍♂️ Usage

### Basic Usage
Run the script as a normal user (the script handles root privileges internally):
```bash
./mount.sh
```

**Note**: The script automatically elevates to root privileges internally using `su --mount-master -c` - you don't need to run it with `su` yourself.

## 🔄 Running at Boot (Automatic Startup)

You can configure the mount script to run automatically when your Android device boots up using Termux:Boot. This ensures your NAS storage is always available without manual intervention.

### Method 1: Using Termux:Boot (Recommended)

1. **Install Termux:Boot app** from F-Droid or GitHub releases

2. **Create the boot directory**:
   ```bash
   mkdir -p ~/.termux/boot/
   ```

3. **Create the boot script**:
   ```bash
   cat << 'EOF' > ~/.termux/boot/mount-nas
   #!/data/data/com.termux/files/usr/bin/bash
   
   # Wait for system initialization and network connectivity
   sleep 30
   
   # Execute mount script with proper environment
   cd ~/Termux-Rclone-NAS-Mount
   ./mount.sh
   
   EOF
   ```

4. **Make it executable**:
   ```bash
   chmod +x ~/.termux/boot/mount-nas
   ```

5. **Grant necessary permissions** to Termux:Boot app in Android settings:
   - Allow "Autostart" or "Boot completion" permission
   - Allow running in background
   - Disable battery optimization for Termux:Boot

6. **Test the boot script** (optional):
   ```bash
   # Test manually before reboot
   ~/.termux/boot/mount-nas
   ```

### Method 2: Using Magisk Service Script (Alternative)

For advanced users with Magisk root:

1. **Create service script**:
   ```bash
   mkdir -p /data/adb/service.d/
   cat << 'EOF' > /data/adb/service.d/termux-nas-mount.sh
   #!/system/bin/sh
   
   # Wait for system to fully boot
   sleep 45
   
   # Execute mount script as Termux user
   su -c "
     export PATH=/data/data/com.termux/files/usr/bin:$PATH
     export HOME=/data/data/com.termux/files/home
     cd /data/data/com.termux/files/home/Termux-Rclone-NAS-Mount
     ./mount.sh
   " &
   
   EOF
   chmod 755 /data/adb/service.d/termux-nas-mount.sh
   ```

### Important Notes for Boot Scripts

- **Wait Time**: Include sufficient wait time (30-45 seconds) to ensure:
  - Network connectivity is established  
  - Termux environment is ready
  - All system services are started

- **Path**: Make sure the script path in `~/.termux/boot/mount-nas` matches your actual installation directory

- **Permissions**: Ensure Termux:Boot has all necessary Android permissions

- **Network Dependency**: Your device must be connected to WiFi/network before the script runs

- **Testing**: Always test your boot script manually before relying on automatic startup

- **Troubleshooting**: Check logs if boot script fails:
  ```bash
  # Check if boot script ran
  ls -la ~/.termux/boot/
  
  # Check mount status after boot
  mount | grep nas3t
  
  # Check rclone processes
  ps | grep rclone
  ```

## 📂 How It Works

### 1. **Initialization**
- Keeps Termux awake using `termux-wake-lock` to prevent interruption
- Waits for system initialization (`INIT_WAIT_TIME=20` seconds)
- Sets up signal handlers for graceful shutdown (cleanup on SIGINT, SIGTERM, SIGQUIT)
- Temporarily disables SELinux enforcement for FUSE mounts

### 2. **Cleanup & Preparation**
- Force unmounts any existing FUSE mounts at the mount point
- Kills any remaining rclone processes to prevent conflicts
- Creates necessary directories:
  - Primary mount point: `/sdcard/nas3t`
  - Android runtime views for app compatibility
- Sets proper ownership (`media_rw:media_rw`) and permissions for Android compatibility

### 3. **Mount Process**
- Executes rclone mount with optimized parameters:
  ```bash
  rclone mount "nas:/NAS3T" "/sdcard/nas3t" \
      --allow-other \
      --gid "9997" \
      --dir-perms "0777" \
      --file-perms "0660" \
      --umask=0 \
      --vfs-cache-mode full \
      --dir-cache-time "72h" \
      --cache-dir "/data/data/com.termux/files/home/.cache" \
      --daemon
  ```

### 4. **Mount Verification**
- Verifies mount success using multiple methods with 30-second timeout:
  - `mountpoint` command (if available)
  - `/proc/mounts` checking
  - Directory accessibility test
- Includes comprehensive retry logic and error reporting

### 5. **Android Integration**
- Creates bind mounts to Android storage views for app compatibility:
  - `/mnt/runtime/write/emulated/0/nas3t` (read-write access for apps)
- Sets appropriate group ownership (`media_rw`) for media app access

### 6. **Graceful Handling**
- **Successful completion**: Keeps processes running, provides status information
- **Interruption handling**: Automatic cleanup of mounts, processes, and wake locks
- **Error cases**: Comprehensive cleanup and helpful diagnostic information

## 🔧 Troubleshooting

### Common Issues

#### Mount Fails
```bash
# Check rclone configuration
rclone config show nas

# Test connection manually
rclone ls nas:/

# Check network connectivity
ping your-nas-ip
```

#### Permission Issues
```bash
# Verify root access (the script will prompt for this)
su -c "id"

# If script fails, check if you can manually access mount-master
su --mount-master -c "mount | grep fuse"
```

#### Android Apps Can't See Files
```bash
# Verify bind mounts
mount | grep nas3t

# Check permissions
ls -la /sdcard/nas3t
```

### Debug Commands
```bash
# Check mount status
mount | grep nas3t

# Check rclone processes
ps | grep rclone

# Check rclone configuration
rclone config show nas

# View mount point contents
ls -la /sdcard/nas3t

# Check bind mounts
mount | grep "/mnt/runtime"

# Check cache directory
ls -la /data/data/com.termux/files/home/.cache
```

## 📱 Android App Access

After successful mounting, your NAS storage will be accessible to Android apps at:
- **File managers**: `/sdcard/nas3t`
- **Media apps**: Through Android Storage Access Framework
- **Document providers**: Via bind mounts in runtime views

## 🛑 Stopping the Mount

### Using the Unmount Script
```bash
# If available, use the provided unmount script
./unmount.sh
```

### Manual Unmount
```bash
# Switch to root user
tsu

# Unmount bind mounts first
umount /mnt/runtime/default/emulated/0/nas3t 2>/dev/null || true
umount /mnt/runtime/read/emulated/0/nas3t 2>/dev/null || true  
umount /mnt/runtime/write/emulated/0/nas3t 2>/dev/null || true

# Unmount main FUSE mount
fusermount -u -z /sdcard/nas3t

# Stop rclone processes
pkill -TERM rclone
sleep 2
pkill -KILL rclone

# Release wake lock (if script is interrupted)
termux-wake-unlock
```

### Using Cleanup (Interrupt the script)
Press `Ctrl+C` if the script is still running to trigger automatic cleanup.

## ⚠️ Important Notes

- **Root Access**: This script requires root access but handles privilege escalation internally
- **No Manual `su` Needed**: Just run the script normally - it will prompt for root when needed
- **Keep Termux Running**: Don't force-close Termux while the mount is active
- **Network Dependency**: Mount will fail if NAS is unreachable
- **SELinux**: Script temporarily disables SELinux enforcement for FUSE mounts

## 🤝 Contributing

Feel free to submit issues, feature requests, or pull requests to improve the script.

## 📄 License

This project is open source. Please check the repository for license details.

## 🔗 Related Resources

- [Termux Wiki](https://wiki.termux.com/)
- [Rclone Documentation](https://rclone.org/)
- [Android Storage Access Framework](https://developer.android.com/guide/topics/providers/document-provider)
- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)

---

## 🌏 中文说明

这是一个在 Termux 中使用 rclone 和 FUSE 挂载 NAS 存储的脚本，使网络存储可以被 Android 应用访问。

### 主要功能
- 自动挂载 NAS 存储
- Android 应用集成
- 强大的错误处理
- 高度可配置
- 内置重试逻辑
- 双语注释支持

### 使用前提
- 已获得 root 权限的 Android 设备（使用 Magisk）
- 已安装 Termux
- 网络连接到您的 NAS 设备
- 已配置 rclone

详细使用说明请参考上方英文部分。
