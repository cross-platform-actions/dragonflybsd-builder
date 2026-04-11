#!/bin/sh

set -exu

setup_path() {
  PATH="/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin:$PATH"
  export PATH
}

bootstrap_pkg() {
  env ASSUME_ALWAYS_YES=YES pkg bootstrap
}

install_extra_packages() {
  pkg install -y bash curl rsync sudo
}

create_secondary_user() {
  echo "$SECONDARY_USER::wheel:::::::/bin/sh:" | adduser -f - -w none -q -S
}

setup_sudo() {
  mkdir -p /usr/local/etc/sudoers.d
  cat <<EOF > "/usr/local/etc/sudoers.d/$SECONDARY_USER"
Defaults:$SECONDARY_USER !requiretty
$SECONDARY_USER ALL=(ALL) NOPASSWD: ALL
EOF

  chmod 440 "/usr/local/etc/sudoers.d/$SECONDARY_USER"
}

set_hostname() {
  sed -i '' 's/^hostname=.*/hostname="runnervmg1sw1.local"/' /etc/rc.conf
}

setup_path
bootstrap_pkg
install_extra_packages
create_secondary_user
setup_sudo
set_hostname
