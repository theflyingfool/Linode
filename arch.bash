#!/bin/bash


## Stolen and edited from https://www.linode.com/stackscripts/view/71751

# <UDF name="username" label="Unprivileged user name" example="This will be the user who will be able to SSH into the server." />
# <UDF name="userpass" label="Unprivileged user password" />
# <UDF name="userpubkey" label="Public key for the user" default="" example="Should look like 'ssh-rsa AAABBB1x2y3z...'" />
# <UDF name="altpubkey" label="Pulls your public key from github using your github username https://github.com/$USERNAME.keys" />
# <UDF name="nopass" label="Disable password authentication for SSH?" oneof="Yes,No" default="Yes" />
# <UDF name="sshport" label="SSH port" default="22" example="It is a good idea to set this to something other than the default of 22."/>
# <UDF name="locale" label="Locale" default="en_US.UTF-8 UTF-8" />
# <UDF name="hostname" label="Host name" example="This is the name of your server."/>
# <UDF name="candy" label="Do you love candy" oneof="Yes,No" default="Yes" />
# <UDF name="timezone" Label="Timezone"       default="America/New_York" example="" />


# Redirect STDOUT and STDERR to a log file
LOGFILE='/root/minimal_arch_stackscript.log'
echo Redirecting output to $LOGFILE. This will take some time ...
exec > $LOGFILE 2>&1

echo Setting locale...
localectl set-locale LANG=$LOCALE
locale-gen

echo Updating the System ...
pacman -Syu --noconfirm

if [ "$CANDY" == 'Yes' ]; then
  sed -i 's/# Misc options/ILoveCandy/' /etc/pacman.conf
fi

echo
echo "### Installing and configuring reflector ..."
pacman -Sy --noconfirm reflector
reflector --protocol https --threads 10 --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
# Reflector hook
mkdir /etc/pacman.d/hooks
cat << 'EOF' >>/etc/pacman.d/hooks/mirrorupgrade.hook
[Trigger]
Operation = Upgrade
Type = Package
Target = pacman-mirrorlist

[Action]
Description = Updating pacman-mirrorlist with reflector and removing pacnew...
When = PostTransaction
Depends = reflector
Exec = /usr/bin/env sh -c "reflector --country 'United States' --latest 200 --age 24 --sort rate --save /etc/pacman.d/mirrorlist; if [[ -f /etc/pacman.d/mirrorlist.pacnew ]]; then rm /etc/pacman.d/mirrorlist.pacnew; fi"
EOF

# Set up the hostname
echo
echo "### Setting hostname ..."
hostnamectl set-hostname $HOSTNAME

# Set up an non-privileged user and sudo
echo
echo "### Adding user ..."
useradd -m -g users -G wheel $USERNAME
echo "### Setting password ..."
passwd $USERNAME <<EOF
$USERPASS
$USERPASS
EOF

# Setup sudoers so wheel group can sudo
echo "### Modifying sudoers ..."
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Don't want to put up with that lecture when I don't have to.
LECTURED="/var/db/sudo/lectured/$USERNAME"
touch $LECTURED
chown root.users $LECTURED

# Set up sshd: disable root login, ensure SSH2, set up password auth, and allow the unprivileged user to login
echo "### Modifying sshd_config ..."
sed -i 's/^[# ]*PermitRootLogin \(yes\|no\)/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i "s/^[# ]*Port [0-9]\+/Port $SSHPORT/" /etc/ssh/sshd_config
sed -i 's/^[# ]*Protocol \([0-9],\?\)\+/Protocol 2/' /etc/ssh/sshd_config
if [ "$NOPASS" == 'Yes' ]; then
    sed -i 's/^[# ]*PasswordAuthentication \(yes\|no\)/PasswordAuthentication no/' /etc/ssh/sshd_config
fi

# Allow only the unprivileged user to log on
echo "AllowUsers $USERNAME" >> /etc/ssh/sshd_config
if [ -n "$USERPUBKEY" ]; then
    sed -i 's/^[# ]*PubkeyAuthentication \(yes\|no\)/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    mkdir -p /home/$USERNAME/.ssh
    echo "$USERPUBKEY" >> /home/$USERNAME/.ssh/authorized_keys
    chown -R "$USERNAME" /home/$USERNAME/.ssh
fi
if [ -n "$ALTPUBKEY" ]; then
    GH_KEY="https://github.com/$ALTPUBKEY.keys"
    mkdir -p /home/$USERNAME/.ssh
    curl "${GH_KEY}" >> /home/$USERNAME/.ssh/authorized_keys
    chown -R "$USERNAME" /home/$USERNAME/.ssh
fi

echo
echo "### Restarting sshd ..."
systemctl restart sshd

echo
echo "### Time Date Setup ..."
timedatectl set-timezone $TIMEZONE
timedatectl set-ntp 1

echo "grab my favorite shit ..."
pacman -Sy tmux vim zsh tmux --noconfirm
chsh -s /bin/zsh $USERNAME
su - $USERNAME -c 'curl "https://raw.githubusercontent.com/theflyingfool/dotfiles.old/master/.zshrc" > ~/.zshrc'
su - $USERNAME -c 'curl "https://raw.githubusercontent.com/theflyingfool/dotfiles.old/master/.vimrc" > ~/.vimrc'
su - $USERNAME -c 'curl "https://raw.githubusercontent.com/theflyingfool/dotfiles.old/master/.tmux.conf" > ~/.tmux.conf'
su - $USERNAME -c 'curl "https://raw.githubusercontent.com/theflyingfool/dotfiles.old/master/.alias" > ~/.alias'



echo
echo "### Done ###"
