set -eux

sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
