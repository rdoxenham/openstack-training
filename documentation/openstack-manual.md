Title: OpenStack Training - Course Manual<br>
Author: Rhys Oxenham <roxenham@redhat.com><br>
Date: March 2013

#**Course Contents**#

1. **Configuring your host machine for OpenStack**
2. **Deploying virtual-machine instances as base infrastructure**
3. **Installation and configuration of Keystone (Identity Service)**
4. **Installation and configuration of Glance (Image Service)**
5. **Installation and configuration of Cinder (Volume Service)**
6. **Installation and configuration of Nova (Compute Services)**
7. **Installation and configuration of Horizon (OpenStack Frontend)**
8. **Deployment of first test instances**
9. **Configuring Nova to provide metadata service for customisation**
10. **Deploying fully customised builds using Puppet/Foreman**
11. **Using Cinder to provide persistent data storage**
12. **Installation and configuration of Quantum (Networking Services)**
13. **Installation and configuration of Swift (Object Storage)**
14. **Deploying and monitoring of instance collections using Heat**
15. **Deploying charge-back and usage monitoring with Celiometer**
16. **Implementing automated deployments with PackStack**

<!--BREAK-->

#**OpenStack Training Overview**

##**Assumptions**

This manual assumes that you're attending instructor-led training classes and that this material be used as a step-by-step guide on how to successfully complete the lab objectives. Prior knowledge gained from the instructor presentations is highly recommended, however for those wanting to complete this training via their own self-learning, a description at each section is available as well as a copy of the course slides.

The course was written with the assumption that you're wanting to deploy OpenStack on-top of a Red Hat based platform, e.g. Red Hat Enterprise Linux or Fedora, and is written specifically for Red Hat's enterprise OpenStack Distribution (http://www.redhat.com/openstack) although the vast majority of the concepts and instructions will apply to other distributions. 

The use of a Linux-based hypervisor (ideally using KVM/libvirt) is highly recommended although not essential, the requirements where necessary are outlined throughout the course but for deployment on alternative platforms it is assumed that this is already configured by yourself. The course advises that four virtual machines are created, each with their own varying degrees of compute resource requirements so please ensure that enough resource is available. Please note that this course helps you deploy a test-bed for knowledge purposes, it's extremely unlikely that any form of production environment would be deployed in this manor.

By undertaking this course you understand that I take no responsibility for any losses incurred and that you are following the instructions at your own free will. A working knowledge of virtualisation, the Linux command-line, networking, storage and scripting will be highly advantageous for anyone following this guide.

##**What to expect from the course**

Upon completion of the course you should fully understand what OpenStack is designed to do, how the components/building-blocks fit together to provide consumable cloud resources and how to install/configure them. You should feel comfortable designing OpenStack-based architectures and how to position the technology. The course goes into a considerable amount of detail but is far from comprenensive; the target of the course is to provide a solid foundation that can be built upon based on the individuals requirements.

<!--BREAK-->

#**The OpenStack Project**

OpenStack is an open-source Infrastructure-as-a-Service (IaaS) initiative for building and managing large groups of compute instances in an on-demand massively scale-out cloud computing environment. The OpenStack project, led by the OpenStack Foundation has many goals, most importantly is it's initiative to support interoperability between cloud services and to provide all of the building blocks required to establish a cloud that mimics what a public cloud offers you. The difference being, you get the benefits of being able to stand it up behind a corporate firewall.

The OpenStack project has had a significant impact on the IT industry, its adoption has been very wide spread and has become the basis of the cloud offerings from vendors such as HP, IBM and Dell. Other organisations such as Red Hat, Ubuntu and Rackspace are putting together 'distributions' of OpenStack and offering it to their customers as a supported platform for building a cloud; it's truly seen as the "Linux of the Cloud". The project currently has contributions from developers all over the world, vendors are actively developing plugins and contributing code to ensure that OpenStack can exploit the latest features that their software/hardware exposes.

OpenStack is made up of many individual components in a modular architecture that can be put together to create different types of clouds depending on the requirements of the organisation, e.g. pure-compute or cloud storage.

TODO: Finish this ;-)


<!--BREAK-->


#**Lab 1: Configuring your host machine for OpenStack**

**Prerequisites:**
* A physical machine installed with either Fedora 18/x86_64 or Red Hat Enterprise Linux 6/x86_64

**Tools used:**
* virsh
* yum 

##**Introduction**

This first lab will prepare your local environment for deploying virtual machine instances that OpenStack will be installed onto; this is considered an "all-in-one" solution, a single physical system where the virtual machines provide the infrastructure. There are a number of tasks that need to be carried out in order to prepare the environment; the OpenStack nodes will need a network to communicate with each other, it will also be extremely beneficial to provide the nodes with access to package repositories via the Internet or repositories available locally, therefore a NAT based network is a great way of establishing network isolation (your hypervisor just becomes the gateway for your OpenStack nodes). The instructions configure a RHEL/Fedora based environment to provide this network configuration and make sure we have persistent addresses.

Estimated completion time: 15 minutes


##**Preparing the environment**

In order to be able to use virtual machines we need to make sure that we have the required hardware and software dependencies.

Firstly, check your physical machine supports accelerated virtualisation:

	# egrep '(vmx|svm)' /proc/cpuinfo

Note: You should see either 'vmx' or 'svm' highlighted for you. If it returns nothing, accelerated virtualisation is not present (if may be disabled in the BIOS).

Next, ensure that libvirt and KVM are installed and running.

	# yum install libvirt qemu-kvm virt-manager virt-install -y && chkconfig libvirtd on && service libvirtd start

If you already have an existing virtual machine infrastructure present on your machine, you may want to back-up your configurations and ensure that virtual machines are shutdown to reduce contention for system resources. This guide assumes that you have completed this and you have a more-or-less vanilla libvirt configuration. 

It's important that the 'default' network is defined in a specific way for the guide to be successful:

	# virsh net-info default
	Name            default
	UUID            d81bb3f3-93cc-4269-81c1-f11d6c404fa0
	Active:         yes
	Persistent:     yes
	Autostart:      yes
	Bridge:         virbr0

If this is not present as above (with the exception of a different uuid), it's recommended that you backup your existing default network configuration and recreate it as follows-

	# mkdir -p /root/libvirt-backup/ && mv /var/lib/libvirt/network/default.xml /root/libvirt-backup/
	# virsh net-destroy default && virsh net-undefine default
	# virsh net-define /usr/share/libvirt/networks/default.xml
	# virsh net-start default

Finally, ensure that the bridge is setup correctly on the host:

	# brctl show
	...
	virbr0		8000.5254005a0a54	yes		virbr0-nic

	# virsh net-info default
	(See above for correct output)


#**Lab 2: Deploying virtual machines**

**Prerequisites:**
* A physical machine configured with a NAT'd network allocated for hosting virtual machines

**Tools used:**
* virt command-line tools (e.g. virsh, virt-install, virt-viewer)

##**Introduction**

OpenStack is made up of a number of distinct components, each having their role in making up a cloud. It's certainly possible to have one single machine (either physical or virtual) providing all of the functions, or a complete OpenStack cloud contained within itself. This, however, doesn't provide any form of high availability/resilience and doesn't make efficient use of resources. Therefore, in a typical deployment, multiple machines will be used, each running a set of components that connect to each other via their open API's. When we look at OpenStack there are two main 'roles' for a machine within the cluster, a 'cloud conductor' and a 'compute node'. A 'cloud conductor' is responsible for orchestration of the cloud, responsibilities include scheduling of instances, running self-service portals, providing rich API's and operating a database store. Whilst a 'compute node' is actually very simple, it's main responsibility is to provide compute resource to the cluster and to accept requests to start instances.

This guide establishes four distinct virtual machines which will make up the core components, their individual purposes will not be explained in this section, the purpose of this lab is to quickly provision these machines as the infrastructure that our OpenStack cluster will be based upon.

Estimated completion time: 30 minutes


##**Preparing the base content**

Assuming that you have a RHEL 6 x86_64 DVD iso available locally, you'll need to provide it for the installation. Alternatively, if you want to install via the network you can do so by using the '--location http://<path to installation tree>' tag within virt-install.

To save time, we'll install a single virtual machine and just clone it afterwards, that way they're all identical.

##**Creating virtual machines**

	# virt-install --name node1 --ram 1000 --file /var/lib/libvirt/images/node1.img \
		--cdrom /path/to/dvd.iso --noautoconsole --vnc --file-size 30 \
		--os-variant rhel6 --network network:default,mac=52:54:00:00:00:01
	# virt-viewer node1

I would advise that you choose a basic or minimal installation option and don't install any window managers, as these are virtual machines we want to keep as much resource as we can available, plus a graphical view is not required. Partition layouts can be set to default at this stage also, just make sure the time-zone is set correctly and that you provide a root password. When asked for a hostname, I suggest you don't use anything unique, just specify "server" or "node" as we will be cloning and want things to be 

After the machine has finished installing it will automatically be shut-down, we have to 'sysprep' it to make sure that it's ready to be cloned, this removes any "hardware"-specific elements so that things like networking come up as if they were created individually. In addition, one step ensures that networking comes up at boot time which it won't do by default if it wasn't chosen in the installer.

	# yum install libguestfs-tools -y && virt-sysprep -d node1
	...

	# virt-edit -d node1 /etc/sysconfig/network-scripts/ifcfg-eth0 -e 's/^ONBOOT=.*/ONBOOT="yes"/'
	
	# virt-clone -o node1 -n node2 -f /var/lib/libvirt/images/node2.img --mac 52:54:00:00:00:02
	Allocating 'node2.img'

	Clone 'node2' created successfully.
	# virt-clone -o node1 -n node3 -f /var/lib/libvirt/images/node3.img --mac 52:54:00:00:00:03
	Allocating 'node3.img'

	Clone 'node3' created successfully.
	# virt-clone -o node1 -n node4 -f /var/lib/libvirt/images/node4.img --mac 52:54:00:00:00:04
	Allocating 'node4.img'

	Clone 'node4' created successfully.

As an *optional* step for convenience, we can leave the virtual machines as DHCP and manually configure the 'default' network within libvirt to present static addresses via DHCP. As we have manually assigned the MAC addresses for our virtual machines we can edit the default network configuration file as follows-

	# virsh net-destroy default
	# virsh net-edit default

	... change the following section...

  	<ip address='192.168.122.1' netmask='255.255.255.0'>
    		<dhcp>
      			<range start='192.168.122.2' end='192.168.122.254' />
    		</dhcp>
  	</ip>

	...to this...

  	<ip address='192.168.122.1' netmask='255.255.255.0'>
    		<dhcp>
      			<range start='192.168.122.2' end='192.168.122.100' />
	      		<host mac='52:54:00:00:00:01' name='node1' ip='192.168.122.101' />
      			<host mac='52:54:00:00:00:02' name='node2' ip='192.168.122.102' />
      			<host mac='52:54:00:00:00:03' name='node3' ip='192.168.122.103' />
      			<host mac='52:54:00:00:00:04' name='node4' ip='192.168.122.104' />
    		</dhcp>
  	</ip>

	(Use 'i' to edit and when finished press escape and ':wq!')

Then, to save changes, run:

	# virsh net-start default

Note: It's possible to configure the guests manually with static IP addresses after the machine has booted up, note that you'll have to use virt-viewer to access the console first

	# virt-viewer nodeX

	-inside the guest-

	# vi /etc/sysconfig/network-scripts/ifcfg-eth0

	-or-

	# system-config-network

For ease of connection to your virtual machine instances, it would be prudent to add the machines to your /etc/hosts file-

	# cat >> /etc/hosts <<EOF
	192.168.122.101 node1
	192.168.122.102 node2
	192.168.122.103 node3
	192.168.122.104 node4
	EOF

Finally, start your virtual machines:

	# virsh start node1 && virsh start node2 && virsh start node3 && virsh start node4

#**Lab 3: Installation and configuration of Keystone (Identity Service)**

**Prerequisites:**
* One of the four virtual machines created in the previous lab
* An active subscription to Red Hat's OpenStack Distribution -or- package repositories available locally

**Tools used:**
* SSH
* subscription-manager

##**Introduction**

Keystone is the identity management component of OpenStack; it supports token-based, username/password and AWS-style logins and is responsible for providing a centralised directory of users mapped to the services they are granted to use. It acts as the common authentication system across the whole of the OpenStack environment and integrates well with existing backend directory services such as LDAP. In addition to providing a centralised repository of users, Keystone provides a catalogue of services deployed in the environment, allowing service discovery with their endpoints (or API entry-points) for access. Keystone is responsible for governance in an OpenStack cloud, it provides a policy framework for allowing fine grained access control over various components and responsibilities in the cloud environment.

As keystone provides the foundation for everything that OpenStack uses this will be the first thing that is installed. For this, we'll take the first node (node1) and turn this into a 'cloud conductor' in which, Keystone will be a crucial part of that infrastructure.

##**Preparing the machine**

	# ssh root@node1

This system was deployed via the DVD, so we'll need to register and subscribe this system to the OpenStack channels. Note that if you have repositories available locally, you can skip these next few steps.

	# subscription-manager register
	(Enter your Red Hat Network credentials)

Next you need to subscribe your system to both a Red Hat Enterprise Linux pool and the OpenStack Enterprise pools-

	# subscription-manager list --available
	(Discover pool ID's for both)

	# subscription-manager subscribe --pool <RHEL Pool> --pool <OpenStack Pool>

At this stage it would be prudent to update to the latest package set available for the base OS:

	# yum update -y

We need to enable the OpenStack repositories next, depending on whether you chose a minimal or basic installation for RHEL, you may already have this package:

	# yum install yum-utils -y

Either way, to enable the repository-

	# yum-config-manager --enable rhel-server-ost-6-folsom-rpms --setopt="rhel-server-ost-6-folsom-rpms.priority=1"
	
	# reboot


##**Installing Keystone**

Now that the system is set-up for package repositories, has been fully updated and has been rebooted, we can proceed with the installation of OpenStack Keystone. 

	# yum install openstack-keystone openstack-utils dnsmasq-utils -y

By default, Keystone uses a back-end MySQL database, whilst it's possible to use other back-ends we'll be using the default in this guide. There's a useful tool called 'openstack-db' which is responsible for setting up the database, initialising the tables and populating it with basic data required to get Keystone started. Note that when you run this command it will automatically deploy MySQL server for you, hence why we didn't install it in the previous step. The script will ask you to choose a new password for MySQL, make sure you remember this!

	# openstack-db --init --service keystone

Keystone uses tokens to authenticate users, even when using username/passwords tokens are used. Once a users identity has been verified with an account/password pair, a short-lived token is issued, these tokens are used by OpenStack components whilst working on behalf of a user. When setting up Keystone we need to create a default administration token which is set in the /etc/keystone/keystone.conf file. We need to generate this and populate the configuration file with this value so that it persists, thankfully there's a simple way of doing this-

	# export SERVICE_TOKEN=$(openssl rand -hex 10)
	# export SERVICE_ENDPOINT=http://192.168.122.101:35357/v2.0
	# echo $SERVICE_TOKEN > /tmp/ks_admin_token

	# openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $SERVICE_TOKEN

Note: As we have exported our SERVICE_TOKEN and SERVICE_ENDPOINT, it will allow us to run keystone commands without specifying a username/password (or token) combination via the command-line; later in this lab we'll write an rc which avoids us having to provide them to administer keystone.

At this point, we can start the Keystone service and enable it at boot-time-

	# service openstack-keystone start
	# chkconfig openstack-keystone on

Recall that Keystone provides the registry of services and their endpoints for interconnectivity, we need to start building up this registry and Keystone itself is not exempt from this list, many services rely on this entry-

	# keystone service-create --name=keystone --type=identity --description="Keystone Identity Service"
	+-------------+----------------------------------+
	|   Property  |              Value               |
	+-------------+----------------------------------+
	| description |    Keystone Identity Service     |
	|      id     | d8c464a629604a3daa11ed511c86dd0a |
	|     name    |             keystone             |
	|     type    |             identity             |
	+-------------+----------------------------------+

Note: The above id is unique to the example set-up that I'm creating as per this guide, expect different if you're following it yourself.

What we've just created is a service, that service needs to have an associated endpoint so that other services know how/where to access their API's. The 'id' from the previously returned command is known as the 'service_id' and we use this to link the two elements together. The endpoint entry has a number of URL fields, public, admin and internal. These differ in that the 'adminurl' is an API exposed primarily for administrating Keystone and the 'publicurl' and 'internalurl' are used for authenticating users and by other services to determine endpoints and for policy enforcement. These endpoints are usually the same but can be useful when there are multiple interfaces in use.

The next step creates this endpoint, it assumes that you're using the IP addresses from Labs 1 & 2, ensure you change these to represent the keystone server and ensure that the service_id is taken from the previous service creation step:

	# keystone endpoint-create --service_id d8c464a629604a3daa11ed511c86dd0a \
		--publicurl 'http://192.168.122.101:5000/v2.0' \
		--adminurl 'http://192.168.122.101:35357/v2.0' \
		--internalurl 'http://192.168.122.101:5000/v2.0'
	+-------------+-----------------------------------+
	|   Property  |               Value               |
	+-------------+-----------------------------------+
	|   adminurl  | http://192.168.122.101:35357/v2.0 |
	|      id     |  ceb6dfc52ec94e89b790dcc9837c98fb |
	| internalurl |  http://192.168.122.101:5000/v2.0 |
	|  publicurl  |  http://192.168.122.101:5000/v2.0 |
	|    region   |             regionOne             |
	|  service_id |  d8c464a629604a3daa11ed511c86dd0a |
	+-------------+-----------------------------------+

What you'll notice in the output is that it also assigns the endpoint to a 'region', or a collection of cloud services. As we didn't specify one, it automatically creates the 'regionOne' region and assigns our endpoint here. When we create additional endpoints we can manually specify the region. For this guide, we won't use multiple regions. 


From Folsom onwards, all OpenStack services utilise Keystone for authentication. As previously mentioned, Keystone uses tokens that are generated via user authentication, e.g. via a username/password combination. The next few steps create a user account, a 'tenant' (a group of users, or a project) and a 'role' which is used to determine permissions cross the stack. 

	# keystone user-create --name admin --pass <password>
	+----------+-----------------------------------+
	| Property |              Value                |
	+----------+-----------------------------------+
	| email    |                                   |
	| enabled  |              True                 |
	| id       | 679cae35033f4bbc9a18aff0c15b7a99  |
	| name     |              admin                |
	| password |               ...                 |
	| tenantId |                                   |
	+----------+-----------------------------------+

	# keystone role-create --name admin
	+----------+----------------------------------+
	| Property |              Value               |
	+----------+----------------------------------+
	|    id    | 729b4119afaf443eadc8e92f74d43103 |
	|   name   |              admin               |
	+----------+----------------------------------+

	# keystone tenant-create --name admin
	+-------------+----------------------------------+
	|   Property  |              Value               |
	+-------------+----------------------------------+
	| description |                                  |
	|   enabled   |               True               |
	|      id     | 4ab1c31fcd2741afa551b5f76146abf6 |
	|     name    |              admin               |
	+-------------+----------------------------------+

Finally we can give the user a role and assign that user to the tenant. Remember that the following command is specific to the id's in *my* environment, you'll need to adjust the id's accordingly based on the results of the previously issued commands:

	# keystone user-role-add --user-id 679cae35033f4bbc9a18aff0c15b7a99 \
		--role-id 729b4119afaf443eadc8e92f74d43103 \
		--tenant-id 4ab1c31fcd2741afa551b5f76146abf6

This admin account will be used for Keystone administration, to save time and to not have to worry about specifying usernames/passwords or tokens on the command-line, it's prudent to create an rc file which will load in environment variables; saving a lot of time. This can be copied & pasted, although make sure you change the IP address to match the end-point of your Keystone server and provide the correct password:

	# cat >> ~/keystonerc_admin <<EOF
	export OS_USERNAME=admin
	export OS_TENANT_NAME=admin
	export OS_PASSWORD=<password>
	export OS_AUTH_URL=http://192.168.122.101:35357/v2.0/
	export PS1='[\u@\h \W(keystone_admin)]\$ '
	EOF

Note: We're using the 35357 port above as this is for the administrator API.

The rc can be used by typing:

	# source ~/keystonerc_admin

You can test the file by logging out of your ssh session, logging back in and trying the following-

	# logout
	# ssh root@node1

	# keystone user-list
	Expecting authentication method via
  	either a service token, --os-token or env[OS_SERVICE_TOKEN], 
  	or credentials, --os-username or env[OS_USERNAME].

	# source ~/keystonerc_admin
	# keystone user-list
	+----------------------------------+-------+---------+-------+
	|                id                |  name | enabled | email |
	+----------------------------------+-------+---------+-------+
	| 679cae35033f4bbc9a18aff0c15b7a99 | admin |   True  |       |
	+----------------------------------+-------+---------+-------+

At this point it would be a good idea to add an additional user account, one that's not an administrator and has limited 'user' rights. This user will be used at a later stage of this guide. Replace <your name> and <password> with your own options, I've used my username 'rdo' for this:

	# keystone user-create --name <your name> --pass <password>
	+----------+-----------------------------------+
	| Property |              Value                |
	+----------+-----------------------------------+
	| email    |                                   |
	| enabled  |               True                |
	| id       | 3b0682e2872849d780ecde00b8d20e4e  |
	| name     |               rdo                 |
	| password |               ...                 |
	| tenantId |                                   |
	+----------+-----------------------------------+

	# keystone role-create --name user
	+----------+----------------------------------+
	| Property |              Value               |
	+----------+----------------------------------+
	|    id    | 9b8ba13292be47b7aae50947b89db5df |
	|   name   |               user               |
	+----------+----------------------------------+

I suggest that you create a tenant named 'training' so that we can refer to this tenant throughout the rest of the guide.

	# keystone tenant-create --name training
	+-------------+----------------------------------+
	|   Property  |              Value               |
	+-------------+----------------------------------+
	| description |                                  |
	|   enabled   |               True               |
	|      id     | 58a576bfd7b34df1afb372c1c905798e |
	|     name    |             training             |
	+-------------+----------------------------------+

Remember to tie the user to the role and place that user into the tenant, utilising your own id's that were returned from your own commands:

	# keystone user-role-add --user-id 3b0682e2872849d780ecde00b8d20e4e \
		--role-id 9b8ba13292be47b7aae50947b89db5df \
		--tenant-id 58a576bfd7b34df1afb372c1c905798e

In the same way that we created a Keystone rc file for the administrator account, we should create one for this new user.


	# cat >> ~/keystonerc_user <<EOF
        export OS_USERNAME=<your user>
        export OS_TENANT_NAME=training
        export OS_PASSWORD=<password>
        export OS_AUTH_URL=http://192.168.122.101:5000/v2.0/
        export PS1='[\u@\h \W(keystone_user)]\$ '
        EOF

Once again noting that we're using port 5000 instead as this is the general purpose API. This can now be tested in the same method as above, a good test is to try and receive a user-list as the non-admin user:

	# source ~/keystonerc_user
	# keystone user-list
	Unable to communicate with identity service: {"error": {"message": "You are not authorized to perform the requested action: admin_required", "code": 403, "title": "Not Authorized"}}. (HTTP 403)

	# source ~/keystonerc_admin
	# keystone user-list
	+----------------------------------+-------+---------+-------+
	|                id                |  name | enabled | email |
	+----------------------------------+-------+---------+-------+
	| 3b0682e2872849d780ecde00b8d20e4e |  rdo  |   True  |       |
	| 679cae35033f4bbc9a18aff0c15b7a99 | admin |   True  |       |
	+----------------------------------+-------+---------+-------+


