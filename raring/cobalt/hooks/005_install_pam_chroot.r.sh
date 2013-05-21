#!/bin/sh
# Lithium hook to set up PAM and chroot so that
# jailed user accounts can be created.

# Only expected to work when run as root on Ubuntu.


export DEBIAN_FRONTEND=noninteractive
export HOOKS_HOME=$(pwd)

pam_install() {
  # Enable PAM modules
  apt-get --assume-yes --quiet --quiet install libpam-chroot libpam-script
}

pam_configure() {
  cp $HOOKS_HOME/config/pam.d-sshd /etc/pam.d/sshd
  cp $HOOKS_HOME/config/pam.d-su /etc/pam.d/su
  cp $HOOKS_HOME/config/pam_script_ses_open /usr/share/libpam-script
  cp $HOOKS_HOME/config/pam_script_acct /usr/share/libpam-script

  # Configure chroot with a group
  echo '@databox                /jails/%u' > /etc/security/chroot.conf
  grep ^databox: /etc/group >/dev/null 2>&1 || groupadd databox

  mkdir -p /jails
}

makejail() {
  BASEJAIL="$1"
  if [ -e /var/run/makejail.done ]
  then
    echo "I think makejail was already successful, skipping"
    return 0
  fi
  apt-get -qq -y install debootstrap
  debootstrap --variant=minbase $(lsb_release -c -s) "$BASEJAIL"
  grep databox /etc/group >> $BASEJAIL/etc/group
  echo "LANG=C.UTF-8" > "${BASEJAIL}/etc/default/locale"

  # make sure can only write crontabs to the mountpoint that is bound here
  mkdir -p "$BASEJAIL/var/spool/cron/crontabs"
  chmod 0 "$BASEJAIL/var/spool/cron/crontabs"

  touch /var/run/makejail.done
}

copy_sshd_config() {
  f=/etc/ssh/sshd_config
  cp "${HOOKS_HOME}/config/sshd_config" ${f}
}


main() {
  pam_install
  pam_configure
  copy_sshd_config
  service ssh reload
  makejail /opt/basejail
}

main
