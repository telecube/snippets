#!/bin/sh

#
# kicks off the basic install
# download and init rc.firewall, configure ssh on a non standard port
# add rc.firewall to cron
# add ntpdate update to cron
# disbale password login for root .. you must have a key on the server
# !! WARNING !! the server will reboot after running this script !!
# remove the last line, the one with "reboot" in it if you don't want it to
# 

# check we have been given a port to run ssh on
if [ -z "$1" ]; then
    echo "Please include an ssh port number"
    echo "Eg; sh init-new-server.sh 2222"
    exit 1
fi

# test the os and version
. /etc/os-release
if [ "$NAME" != "Ubuntu" ] || [ "$VERSION_ID" != "14.04" ]; then
    echo "Sorry, this script only supports Ubuntu version 14.04"
    echo "You are on: $NAME $VERSION_ID"
    exit 1
fi

# install common tools
apt-get update
apt-get install -y ntpdate htop iftop wget nano iptables

# get rc.firewall
if [ -f /etc/rc.firewall ];
then
   echo "/etc/rc.firewall exists."
else
	wget -P /etc/ https://github.com/telecube/snippets/raw/master/bash/rc.firewall

	chmod 0755 /etc/rc.firewall

	# remove the port 22 from the firewall and restart install
	sed -i 's/PERMIT="$PERMIT 22"/PERMIT="$PERMIT $1"/' /etc/rc.firewall

	/etc/rc.firewall

	echo "Downloaded and set rc.firewall ..."
fi

# enable ssh port 
STR="Port $1"
if grep -Fxq "$STR" /etc/ssh/sshd_config
then
    # ssh port found
    echo "Port $1 already configured"
else
    # ssh port not found
	sed -i '/Port 22/a Port $1\n' /etc/ssh/sshd_config

	echo "Added port $1 to sshd_config ..."
fi

# make sure password auth is off
STR="PasswordAuthentication yes"
if grep -Fxq "$STR" /etc/ssh/sshd_config
then
    # code if found
    echo "PasswordAuthentication not enabled"
else
    # code if not found
	sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

	echo "Removed password authentication ..."
fi

# restart ssh
service ssh restart

# get a random minute
RAND_MIN=$(shuf -i 1-59 -n 1)

# add the rc.firewall script to cron
crontab -l | { cat; echo "@reboot /etc/rc.firewall  >/dev/null 2>&1"; } | crontab -
crontab -l | { cat; echo "$RAND_MIN	*	*	*	*	/usr/sbin/ntpdate -b -s ntp0.cs.mu.OZ.AU  >/dev/null 2>&1"; } | crontab -

echo "\nDone .. server will reboot now!"

sleep 3

reboot



