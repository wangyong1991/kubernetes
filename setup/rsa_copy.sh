#!/bin/expect

set USER [lindex $argv 0]
set PASSWD [lindex $argv 1]
set HOST [lindex $argv 2]

# echo $HOST; 
spawn ssh-copy-id -i k8s_rsa.pub ${USER}@${HOST}
expect "password:"
send "${PASSWD}\r"
interact

