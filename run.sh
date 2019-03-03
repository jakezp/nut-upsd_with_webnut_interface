#!/bin/bash

# Auto generate passwords if not provided
if [[ -z "$API_PASSWORD" ]];
then
   API_PASSWORD=$(date | md5sum | cut -c1,5,9,7,4,3,5,1,7,2,3)
fi

if [[ -z "$ADMIN_PASSWORD" ]];
then
   ADMIN_PASSWORD=$(date | md5sum | cut -c1,5,9,7,4,3,5,1,7,2,3)
fi

# Populate nut-upsd config files
cat >/etc/nut/ups.conf <<EOF
[$UPS_NAME]
	desc = "$UPS_DESC"
	driver = $UPS_DRIVER
	port = $UPS_PORT
EOF

cat >/etc/nut/upsd.conf <<EOF
LISTEN 0.0.0.0 3493
EOF

cat >/etc/nut/upsd.users <<EOF
[admin]
	password = $ADMIN_PASSWORD
	actions = set
	actions = fsd
	instcmds = all
[$API_USER]
	password = $API_PASSWORD
	upsmon master
EOF

cat >/etc/nut/upsmon.conf <<EOF
MONITOR $UPS_NAME@localhost 1 $API_USER $API_PASSWORD master
NOTIFYFLAG ONLINE   SYSLOG+WALL
SHUTDOWNCMD "$SHUTDOWN_CMD"
EOF

chgrp -R nut /etc/nut /dev/bus/usb
chmod -R o-rwx /etc/nut

# Create webNUT config file
cat >/app/webNUT/webnut/config.py <<EOF
server = '127.0.0.1'
port = '3493'
username = '$API_USER'
password = '$API_PASSWORD'
EOF

sed -i 's/MODE=none/MODE=standalone/g' /etc/nut/nut.conf

# Start nut services in order
/sbin/upsdrvctl start
sleep 5
/sbin/upsd
sleep 5
/sbin/upsmon
sleep 10
cd /app/webNUT/webnut
pserv ../production.ini
