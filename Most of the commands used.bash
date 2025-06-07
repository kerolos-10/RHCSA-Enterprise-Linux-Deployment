Phase 1: System Preparation and User Environment

# Change hostname
hostnamectl set-hostname intranet.technova.local
# Create groups
groupadd dev_team
groupadd hr_team
groupadd it_team
groupadd sales_team
# Create users and assign groups
useradd -m -s /bin/bash -G dev_team alice
useradd -m -s /bin/bash -G hr_team bob
useradd -m -s /bin/bash -G it_team carol
useradd -m -s /bin/bash -G sales_team dave
useradd -m -s /bin/bash -G dev_team erin
useradd -m -s /bin/bash -G it_team frank
# Set passwords (manually for each user)
passwd alice
passwd bob
passwd carol
passwd dave
passwd erin
passwd frank
# Force password change on first login
chage -d 0 alice
chage -d 0 bob
chage -d 0 carol
chage -d 0 dave
=================================================
Phase 2: Directory & Permission Setup

# Create directories
mkdir -p /srv/dev /srv/hr /srv/it /srv/sales
# Set group ownership
chown -R :dev_team /srv/dev
chown -R :hr_team /srv/hr
chown -R :it_team /srv/it
chown -R :sales_team /srv/sales
# Set permissions with SetGID
chmod 2770 /srv/dev
chmod 2770 /srv/hr
chmod 2770 /srv/it
chmod 2770 /srv/sales
# Configure ACLs
setfacl -m u:frank:rwX /srv/dev
setfacl -m u:frank:rwX /srv/hr
setfacl -m u:frank:rwX /srv/it
setfacl -m u:frank:rwX /srv/sales
setfacl -m u:bob:r-- /srv/sales
# Create shared temp folder
mkdir /srv/public_temp
chmod 1777 /srv/public_temp
===========================================
Phase 3: Storage and LVM Setup

# Create Physical Volume
pvcreate /dev/sdb
# Create Volume Group
vgcreate vg_deptdata /dev/sdb
# Create Logical Volumes
lvcreate -n lv_dev -L 1G vg_deptdata
lvcreate -n lv_hr -L 500M vg_deptdata
lvcreate -n lv_it -L 1G vg_deptdata
lvcreate -n lv_sales -L 1G vg_deptdata
# Format with XFS
mkfs.xfs /dev/vg_deptdata/lv_dev
mkfs.xfs /dev/vg_deptdata/lv_hr
mkfs.xfs /dev/vg_deptdata/lv_it
mkfs.xfs /dev/vg_deptdata/lv_sales
# Add to /etc/fstab (example for /srv/dev)
echo "/dev/vg_deptdata/lv_dev /srv/dev xfs defaults 0 0" >> /etc/fstab
# Repeat for other mount points
# Mount all
mount -a
# Enable quotas (for /srv/hr and /srv/sales)
sed -i 's/defaults/defaults,usrquota,grpquota/' /etc/fstab
mount -o remount /srv/hr
mount -o remount /srv/sales
quotacheck -cum /srv/hr
quotacheck -cum /srv/sales
quotaon /srv/hr
quotaon /srv/sales
# Set user quotas
setquota -u username 100000 150000 0 0 /srv/hr  # Repeat per user
setquota -u username 100000 150000 0 0 /srv/sales
=========================================================
Phase 4: Security Hardening

# Configure sudo for frank
echo "frank ALL=(ALL) NOPASSWD: /usr/sbin/useradd, /usr/sbin/userdel, /usr/sbin/usermod, /usr/bin/yum, /usr/bin/dnf" > /etc/sudoers.d/frank
# SSH configuration (edit /etc/ssh/sshd_config)
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
echo "AllowGroups it_team" >> /etc/ssh/sshd_config
systemctl restart sshd
# Generate SSH key for frank (as frank user)
su - frank -c "ssh-keygen -t rsa"
# SELinux enforcement
setenforce 1
sed -i 's/SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
# Configure firewall
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-icmp-block-inversion
firewall-cmd --permanent --add-icmp-block=echo-reply
firewall-cmd --permanent --add-icmp-block=echo-request
firewall-cmd --reload
=============================================
Phase 5: Internal Web Portal

# Install Apache
yum install -y httpd
# Create index.html
echo '<h1>Welcome to TechNova Internal Portal</h1>' > /var/www/html/index.html
echo '<p>Only accessible inside the company.</p>' >> /var/www/html/index.html
# Start and enable service
systemctl start httpd
systemctl enable httpd
# Set SELinux context
restorecon -Rv /var/www/html/
===========================================
Phase 6: Automation & Scripting

# Create backup script /usr/local/bin/backup_dept.sh
cat > /usr/local/bin/backup_dept.sh << 'EOF'
#!/bin/bash
date=$(date +%F)
for dept in dev hr it sales; do
    tar -czf "/backups/${dept}_${date}.tar.gz" "/srv/${dept}"
    logger "Backup for $dept completed successfully."
done
EOF
# Make script executable
chmod +x /usr/local/bin/backup_dept.sh
# Create cron job
echo "0 1 * * * root /usr/local/bin/backup_dept.sh" > /etc/cron.d/backup_dept
# Schedule broadcast message
echo 'wall "System maintenance will occur tonight at 1:00 AM. Save your work!"' | at 17:00
===================================================
Phase 7: Troubleshooting & Logs

# Check failed SSH logins
grep 'Failed password' /var/log/secure
# Check backup logs
grep 'Backup for' /var/log/messages
# Review user activity
last
who
journalctl -n 50
# Fix fstab errors (in rescue mode)
mount -o remount,rw /
vim /etc/fstab
