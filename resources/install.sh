#!/bin/sh

# Install DragonFly BSD from the live CD to disk.
# Based on https://github.com/DragonFlyBSD/dragonfly-packer

set -eux

DISK="${DISK:-da0}"
ROOT_PASSWORD="${ROOT_PASSWORD:-runner}"

# --- Partition disk using MBR + disklabel64 ---
dd if=/dev/zero of="/dev/${DISK}" bs=32k count=16
fdisk -IB "${DISK}"
sleep 1

# Write blank disklabel with boot blocks.
# The 'auto' keyword creates the label geometry and partition 'c' (whole
# slice) but does NOT create usable partitions -- device nodes like
# /dev/da0s1a only appear after partitions are added via the editor.
disklabel64 -r -w -B "${DISK}s1" auto

# Non-interactively add partitions using EDITOR override.
# disklabel64 -e writes through the kernel, which creates device nodes.
cat > /tmp/edit_label.sh <<'SCRIPT'
#!/bin/sh
sed -i '' '/^  a:/d' "$1"
cat >> "$1" <<EOF
  a:  1g          0    4.2BSD
  b:  1g          *    swap
  d:  *           *    HAMMER2
EOF
SCRIPT
chmod +x /tmp/edit_label.sh
EDITOR=/tmp/edit_label.sh disklabel64 -e "${DISK}s1"

sleep 1

# Verify device nodes were created
ls "/dev/${DISK}s1a" "/dev/${DISK}s1d"

# --- Create filesystems ---
newfs "/dev/${DISK}s1a"
newfs_hammer2 -L ROOT "/dev/${DISK}s1d"

# --- Mount filesystems ---
mount "/dev/${DISK}s1d@ROOT" /mnt

mkdir -p /mnt/boot
mount -t ufs "/dev/${DISK}s1a" /mnt/boot

# --- Create directory layout ---
mtree -deU  -f /etc/mtree/BSD.root.dist    -p /mnt
mtree -deiU -f /etc/mtree/BSD.var.dist     -p /mnt/var
mtree -deU  -f /etc/mtree/BSD.usr.dist     -p /mnt/usr
mtree -deU  -f /etc/mtree/BSD.include.dist -p /mnt/usr/include
mkdir -p /mnt/home /mnt/proc

# --- Copy system from live CD ---
cpdup -I /               /mnt
cpdup -I /root           /mnt/root
cpdup -I /boot           /mnt/boot
cpdup -I /var            /mnt/var
cpdup -I /usr/local/etc  /mnt/usr/local/etc

# Replace live CD etc with hard disk version
cd /mnt
rm -rf README* autorun* dflybsd.ico index.html
rm -rf etc
mv etc.hdd etc

# SSL certificate link
(cd /mnt/etc/ssl && ln -sf ../../usr/local/share/certs/ca-root-nss.crt cert.pem)

# --- Configure boot ---
echo '-S115200 -D' > /mnt/boot.config

cat > /mnt/boot/loader.conf <<EOF
vfs.root.mountfrom="hammer2:/dev/${DISK}s1d@ROOT"
boot_serial="YES"
comconsole_speed="115200"
console="comconsole"
EOF

# Enable serial console getty
sed -i '' 's|^ttyd0.*off.*|ttyd0\t"/usr/libexec/getty std.115200"\tvt100\ton\tsecure|' /mnt/etc/ttys

# --- Configure fstab ---
cat > /mnt/etc/fstab <<EOF
/dev/${DISK}s1d@ROOT    /          hammer2  rw  1  1
/dev/${DISK}s1a         /boot      ufs      rw  2  2
/dev/${DISK}s1b         none       swap     sw  0  0
proc                    /proc      procfs   rw  0  0
EOF

# --- Configure rc.conf ---
cat > /mnt/etc/rc.conf <<EOF
hostname="dragonflybsd"
ifconfig_vtnet0="DHCP"
tmpfs_tmp="YES"
tmpfs_var_run="YES"
sshd_enable="YES"
dntpd_enable="YES"
EOF

# --- Configure SSH ---
# OpenSSH uses the FIRST matching directive, so we must modify in-place
# rather than appending (which would be ignored).
sed -i '' \
  -e 's/^#*PermitRootLogin.*/PermitRootLogin yes/' \
  -e 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' \
  -e 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords yes/' \
  -e 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' \
  -e 's/^#*UseDNS.*/UseDNS no/' \
  /mnt/etc/ssh/sshd_config
echo 'AcceptEnv *' >> /mnt/etc/ssh/sshd_config

# Generate SSH host keys directly (not in chroot, to avoid devfs issues)
ssh-keygen -t rsa     -f /mnt/etc/ssh/ssh_host_rsa_key     -N ''
ssh-keygen -t ecdsa   -f /mnt/etc/ssh/ssh_host_ecdsa_key   -N ''
ssh-keygen -t ed25519 -f /mnt/etc/ssh/ssh_host_ed25519_key -N ''

# --- Configure user database ---
pwd_mkdb -p -d /mnt/etc /mnt/etc/master.passwd
pw -V /mnt/etc userdel installer 2>/dev/null || true

# --- Set root password and shell ---
# Root's shell must be /bin/sh (not csh) for Packer's provisioners to work,
# since Packer sets environment variables using Bourne shell syntax.
mount -t devfs devfs /mnt/dev
echo "${ROOT_PASSWORD}" | chroot /mnt pw usermod root -s /bin/sh -h 0
umount /mnt/dev

# --- Unmount ---
cd /
umount /mnt/boot
umount /mnt
