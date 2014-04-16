#!/bin/bash
# OpenStack Labs Restore Script

source keystonerc_admin
keystone user-create --name demo --pass redhat
keystone tenant-create --name demo
keystone user-role-add --user demo --role Member --tenant demo

cat >> ~/keystonerc_demo <<EOF
export OS_USERNAME=demo
export OS_TENANT_NAME=demo
export OS_PASSWORD=redhat
export OS_AUTH_URL=http://localhost:5000/v2.0/
export PS1='[\u@\h \W(keystone_demo)]\$ '
EOF

source keystonerc_demo
glance image-download --file cirros-0.3.1-x86_64-disk.img --progress "Cirros 0.3.1"
glance image-create --name "My Cirros Image" --is-public false --disk-format qcow2 --container-format bare --file ~/cirros-0.3.1-x86_64-disk.img

neutron net-create int
neutron subnet-create int 30.0.0.0/24 --name my_subnet
neutron router-create my_router
neutron router-gateway-set my_router external
neutron router-interface-add my_router my_subnet

source keystonerc_admin
nova flavor-create my_new_flavor 6 1024 20 2
source keystonerc_demo
neutron security-group-rule-create --protocol icmp --remote-ip-prefix 0.0.0.0/0 default
neutron security-group-rule-create --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 192.168.122.0/24 default

ssh-keygen -q -b 1024 -t rsa -f /root/.ssh/id_rsa -N ""
nova keypair-add --pub-key /root/.ssh/id_rsa.pub mypublickey