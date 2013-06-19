Title: OpenStack Training - Course Manual<br>
Author: Rhys Oxenham <roxenham@redhat.com><br>
Date: March 2013

#**Course Contents**#

1. **Configuring your host machine for OpenStack**
2. **Deploying virtual-machine instances as base infrastructure**
3. **Installation and configuration of Keystone (Identity Service)**
4. **Installation and configuration of Glance (Image Service)**
5. **Installation and configuration of Cinder (Volume Service)**
6. **Installation and configuration of Quantum (Networking Services)**
7. **Installation and configuration of Nova (Compute Services)**
8. **Installation and configuration of Horizon (OpenStack Frontend)**
9. **Deployment of Instances**
10. **Attaching Floating IP's to Instances**
11. **Configuring the Metadata Service for Customisation**
12. **Using Cinder to provide persistent data storage**
13. **Deploying and monitoring of instance collections using Heat**
14. **Deploying charge-back and usage monitoring with Celiometer**

<!--BREAK-->

#**OpenStack Training Overview**

##**Assumptions**

This manual assumes that you're attending instructor-led training classes and that this material be used as a step-by-step guide on how to successfully complete the lab objectives. Prior knowledge gained from the instructor presentations is highly recommended, however for those wanting to complete this training via their own self-learning, a description at each section is available as well as a copy of the course slides.

The course was written with the assumption that you're wanting to deploy Red Hat OpenStack on-top of a Red Hat Enterprise Linux, e.g. Red Hat Enterprise Linux or Fedora, and is written specifically for Red Hat's enterprise OpenStack Distribution (http://www.redhat.com/openstack) although the vast majority of the concepts and instructions will apply to other distributions, including RDO.

The use of a Linux-based hypervisor (ideally using KVM/libvirt) is highly recommended although not essential, the requirements where necessary are outlined throughout the course but for deployment on alternative platforms it is assumed that this is already configured by yourself. The course advises that two virtual machines are created, each with their own varying degrees of compute resource requirements so please ensure that enough resource is available. Please note that this course helps you deploy a test-bed for knowledge purposes, it's extremely unlikely that any form of production environment would be deployed in this manor.

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

This first lab will prepare your local environment for deploying virtual machine instances that OpenStack will be installed onto; this is considered an "all-in-one" solution, a single physical system where the virtual machines provide the infrastructure. There are a number of tasks that need to be carried out in order to prepare the environment; the OpenStack nodes will need a network to communicate with each other (e.g. a libvirt-NAT interface) and an isolated network for inter-instance communication, it will also be extremely beneficial to provide the nodes with access to package repositories via the Internet or repositories available locally, therefore a NAT based network is a great way of establishing network isolation (your hypervisor just becomes the gateway for your OpenStack nodes). The instructions configure a RHEL/Fedora based environment to provide this network configuration and make sure we have persistent addresses.

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
* A physical machine configured with a NAT'd network allocated for hosting virtual machines as well as an isolated vSwitch network

**Tools used:**
* virt command-line tools (e.g. virsh, virt-install, virt-viewer)

##**Introduction**

OpenStack is made up of a number of distinct components, each having their role in making up a cloud. It's certainly possible to have one single machine (either physical or virtual) providing all of the functions, or a complete OpenStack cloud contained within itself. This, however, doesn't provide any form of high availability/resilience and doesn't make efficient use of resources. Therefore, in a typical deployment, multiple machines will be used, each running a set of components that connect to each other via their open API's. When we look at OpenStack there are two main 'roles' for a machine within the cluster, a 'cloud controller' and a 'compute node'. A 'cloud controller' is responsible for orchestration of the cloud, responsibilities include scheduling of instances, running self-service portals, providing rich API's and operating a database store. Whilst a 'compute node' is actually very simple, it's main responsibility is to provide compute resource to the cluster and to accept requests to start instances.

This guide establishes four distinct virtual machines which will make up the core components, their individual purposes will not be explained in this section, the purpose of this lab is to quickly provision these machines as the infrastructure that our OpenStack cluster will be based upon.

Estimated completion time: 30 minutes


##**Preparing the base content**

Assuming that you have a RHEL 6 x86_64 DVD iso available locally, you'll need to provide it for the installation. Alternatively, if you want to install via the network you can do so by using the '--location http://<path to installation tree>' tag within virt-install.

To save time, we'll install a single virtual machine and just clone it afterwards, that way they're all identical. If you're following this guide as part of instructor-led training, a pre-built image is available saving you even more time. Please ask the instructor for pre-built libvirt definitions and disk images, available in both qcow2 and vmdk formats, then skip the virt-install steps.

##**Creating virtual machines**

Only do this if you don't have the pre-built images...

	# virt-install --name openstack-controller --ram 1000 --file /var/lib/libvirt/images/openstack-controller.img \
		--cdrom /path/to/dvd.iso --noautoconsole --vnc --file-size 30 \
		--os-variant rhel6 --network network:default,mac=52:54:00:00:00:01
	# virt-viewer openstack-controller

I would advise that you choose a basic or minimal installation option and don't install any window managers, as these are virtual machines we want to keep as much resource as we can available, plus a graphical view is not required. Partition layouts can be set to default at this stage also, just make sure the time-zone is set correctly and that you provide a root password. When asked for a hostname, I suggest you don't use anything unique, just specify "server" or "node" as we will be cloning and want things to be 

After the machine has finished installing it will automatically be shut-down, we have to 'sysprep' it to make sure that it's ready to be cloned, this removes any "hardware"-specific elements so that things like networking come up as if they were created individually. In addition, one step ensures that networking comes up at boot time which it won't do by default if it wasn't chosen in the installer.

	# yum install libguestfs-tools -y && virt-sysprep -d openstack-controller
	...

	# virt-edit -d openstack-controller /etc/sysconfig/network-scripts/ifcfg-eth0 -e 's/^ONBOOT=.*/ONBOOT="yes"/'
	
	# virt-clone -o openstack-controller -n openstack-compute1 -f /var/lib/libvirt/images/openstack-compute1.img --mac 52:54:00:00:00:02
	Allocating 'openstack-compute1.img'

	Clone 'openstack-compute1' created successfully.
	
----- END HERE -----

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
      			<range start='192.168.122.2' end='192.168.122.9' />
	      		<host mac='52:54:00:00:00:01' name='openstack-controller' ip='192.168.122.101' />
      			<host mac='52:54:00:00:00:02' name='openstack-compute1' ip='192.168.122.102' />
    		</dhcp>
  	</ip>

	(Use 'i' to edit and when finished press escape and ':wq!')

Then, to save changes, run:

	# virsh net-start default

For ease of connection to your virtual machine instances, it would be prudent to add the machines to your /etc/hosts file-

	# cat >> /etc/hosts <<EOF
	192.168.122.101 openstack-controller
	192.168.122.102 openstack-compute1
	EOF

Finally, start your first virtual machine that'll be used in the next lab:

	# virsh start openstack-controller

#**Lab 3: Installation and configuration of Keystone (Identity Service)**

**Prerequisites:**
* A machine built to be the Cloud Controller (i.e. openstack-controller)
* An active subscription to Red Hat's OpenStack Distribution -or- package repositories available locally

**Tools used:**
* SSH
* subscription-manager
* yum
* OpenStack Keystone

##**Introduction**

Keystone is the identity management component of OpenStack; it supports token-based, username/password and AWS-style logins and is responsible for providing a centralised directory of users mapped to the services they are granted to use. It acts as the common authentication system across the whole of the OpenStack environment and integrates well with existing backend directory services such as LDAP. In addition to providing a centralised repository of users, Keystone provides a catalogue of services deployed in the environment, allowing service discovery with their endpoints (or API entry-points) for access. Keystone is responsible for governance in an OpenStack cloud, it provides a policy framework for allowing fine grained access control over various components and responsibilities in the cloud environment.

As keystone provides the foundation for everything that OpenStack uses this will be the first thing that is installed. For this, we'll take the first node (openstack-controller) and turn this into a 'cloud controller' in which, Keystone will be a crucial part of that infrastructure.

##**Preparing the machine**

	# ssh root@openstack-controller

We'll need to register and subscribe this system to the OpenStack channels. Note that if you have repositories available locally, you can skip these next few steps.

	# subscription-manager register
	(Enter your Red Hat Network credentials)

Next you need to subscribe your system to both a Red Hat Enterprise Linux pool and the OpenStack Enterprise pools-

	# subscription-manager list --available
	(Discover pool ID's for both)

	# subscription-manager subscribe --pool <RHEL Pool> --pool <OpenStack Pool>

We need to enable the OpenStack repositories next:

	# yum install yum-utils -y
	# yum-config-manager --enable rhel-server-ost-6-3-rpms --setopt="rhel-server-ost-6-3-rpms.priority=1"
	
Install the Red Hat OpenStack-specific Kernel and associated packages, this is down to the standard Red Hat kernel not being shipped with namespace support. Please ask your instructor for these files, if you're not following an instructor-led training course then please ask your Red Hat representative.

	# yum localinstall /path/to/rpms/*.rpm -y	
	# yum update -y
	
	# reboot

##**Installing Keystone**

Now that the system is set-up for package repositories, has been fully updated and has been rebooted, we can proceed with the installation of OpenStack Keystone. 

	# yum install openstack-keystone openstack-utils dnsmasq-utils -y

By default, Keystone uses a back-end MySQL database, whilst it's possible to use other back-ends we'll be using the default in this guide. There's a useful tool called 'openstack-db' which is responsible for setting up the database, initialising the tables and populating it with basic data required to get Keystone started. Note that when you run this command it will automatically deploy MySQL server for you, hence why we didn't install it in the previous step. You can choose an alternative password than the one listed below but remember it!

	# openstack-db --init --service keystone

Keystone uses tokens to authenticate users, even when using username/passwords tokens are used. Once a users identity has been verified with an account/password pair, a short-lived token is issued, these tokens are used by OpenStack components whilst working on behalf of a user. When setting up Keystone we need to create a default administration token which is set in the /etc/keystone/keystone.conf file. We need to generate this and populate the configuration file with this value so that it persists, thankfully there's a simple way of doing this-

	# export SERVICE_TOKEN=$(openssl rand -hex 10)
	# export SERVICE_ENDPOINT=http://192.168.122.101:35357/v2.0
	# echo $SERVICE_TOKEN > /tmp/ks_admin_token

	# openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $SERVICE_TOKEN

Note: As we have exported our SERVICE_TOKEN and SERVICE_ENDPOINT, it will allow us to run keystone commands without specifying a username/password (or token) combination via the command-line; later in this lab we'll write an rc which avoids us having to provide them to administer keystone.

OpenStack Keystone uses PKI to validate token authenticity, the appropriate SSL certificates must be generated, for future reference custom configuration can be made in /etc/keystone/ssl/certs/openssl.conf, but for the purposes of this training we'll use the defaults. There's a current bug with keystone-manage in that it doesn't configure the permissions correctly for the keystone process to access the certificates, so we'll workaround that:

	# keystone-manage pki_setup
	# chown -R keystone:keystone /etc/keystone/ssl

At this point, we can start the Keystone service and enable it at boot-time-

	# service openstack-keystone start
	# chkconfig openstack-keystone on

##**Creating a Keystone Service**

Recall that Keystone provides the registry of services and their endpoints for interconnectivity, we need to start building up this registry and Keystone itself is not exempt from this list, many services rely on this entry-

	# keystone service-create --name keystone --type identity --description "Keystone Identity Service"
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


##**Creating Users**

From Folsom onwards, all OpenStack services utilise Keystone for authentication. As previously mentioned, Keystone uses tokens that are generated via user authentication, e.g. via a username/password combination. The next few steps create a user account, a 'tenant' (a group of users, or a project) and a 'role' which is used to determine permissions across the stack. You can choose your own password here, just remember what it is as we'll use it later:

	# keystone user-create --name admin --pass <password>
	+----------+-----------------------------------+
	| Property |              Value                |
	+----------+-----------------------------------+
	| email    |                                   |
	| enabled  |              True                 |
	| id       | 679cae35033f4bbc9a18aff0c15b7a99  |
	| name     |              admin                |
	| tenantId |                                   |
	+----------+-----------------------------------+

	# keystone role-create --name admin
	+----------+----------------------------------+
	| Property |              Value               |
	+----------+----------------------------------+
	|    id    | 729b4119afaf443eadc8e92f74d43103 |
	|   name   |              admin               |
	+----------+----------------------------------+
	
Note: All roles are respected by 'policy.json' on the Keystone machine. The 'admin' role used above is one that comes 'out of the box' in OpenStack. You can create roles to do just about anything in a RBAC configuration, but remember that roles won't be respected unless they are detailed in policy.json.

	# keystone tenant-create --name admin
	+-------------+----------------------------------+
	|   Property  |              Value               |
	+-------------+----------------------------------+
	| description |                                  |
	|   enabled   |               True               |
	|      id     | 4ab1c31fcd2741afa551b5f76146abf6 |
	|     name    |              admin               |
	+-------------+----------------------------------+

Finally we can give the user a role and assign that user to the tenant. Note that we're using usernames, roles and tenants by their name here, it's possible to use their id's instead. 

	# keystone user-role-add --user admin --role admin --tenant admin

This admin account will be used for Keystone administration, to save time and to not have to worry about specifying usernames/passwords or tokens on the command-line, it's prudent to create an rc file which will load in environment variables; saving a lot of time. This can be copied & pasted, although make sure you change the IP address to match the end-point of your Keystone server and provide the correct password:

	# cat >> ~/keystonerc_admin <<EOF
	export OS_USERNAME=admin
	export OS_TENANT_NAME=admin
	export OS_PASSWORD=<password>
	export OS_AUTH_URL=http://192.168.122.101:35357/v2.0/
	export PS1='[\u@\h \W(keystone_admin)]\$ '
	EOF

Note: We're using the 35357 port above as this is for the administrator API, all other requests go via port 5000.

You can test the file by logging out of your ssh session, logging back in and trying the following-

	# logout
	# ssh root@openstack-controller

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

Remember to tie the user to the role and place that user into the tenant, utilising your own value for your user:

	# keystone user-role-add --user <your user> --role user --tenant training

In the same way that we created a Keystone rc file for the administrator account, we should create one for this new user.

	# cat >> ~/keystonerc_user <<EOF
	export OS_USERNAME=<your user>
	export OS_TENANT_NAME=training
	export OS_PASSWORD=<your password>
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

To accomodate massive scalability, OpenStack was built using AMQP-based messaging for communication. We're going to install qpidd on our 'cloud conductor' node but we'll disable authentication just for convenience. In a production environment authentication would certainly be enabled and configured properly. We need to install this now as later on in the guide we'll rely on this message bus being available.

	# yum install qpid-cpp-server -y
	# sed -i 's/auth=.*/auth=no/g' /etc/qpidd.conf
	# service qpidd start && chkconfig qpidd on


#**Lab 4: Installation and configuration of Glance (Image Service)**

**Prerequisites:**
* Keystone installed and configured as per Lab 3
* A pre-created Linux-based disk image or access to virtual machines created in Lab 2

**Tools used:**
* OpenStack Keystone
* OpenStack Glance
* openstack-db
* openstack-config
* ssh

##**Introduction**

Glance is OpenStack's image service, it provides a mechanism for discovering, registering and retrieving virtual machine images. These images are typically standardised and generalised so that they will require post-boot configuration applied. Glance supports a wide variety of disk image formats, including raw, qcow2, vmdk, ami and iso, all of which can be stored in multiple types of back-ends, including OpenStack Swift (OpenStack's Object Storage Service, which we'll cover in a later lab) although by default it will use the local filesystem. When a user requests an instance within the cloud, it's Glance's responsibility to provide that image and allow it to be retrieved prior to instantiation.

Glance stores metadata alongside each image which helps identify it and describe the image, it can accomodate for multiple container types, e.g. an image could be completely self contained such as a qcow2 image however an image could also be just a kernel or an initrd file which need to be tied together to successfully boot an instance of that machine. Glance is made up of two components, the glance-registry which is the actual image registry service and glance-api which provides the end-point to the rest of the OpenStack services.

Keystone optionally is used to store the end-point for Glance and provides a mechanism for authentication and policy enforcement, e.g. who owns images and who is allowed to use them. This guide will show you how to integrate Glance with Keystone.

##**Installing Glance**

As we'll be using the same 'cloud controller' node as before, i.e. the one we deployed Keystone onto, we need to open up a shell to that machine:

	# ssh root@openstack-controller

Then install the required components:

	# yum install openstack-glance -y

Glance makes use of MySQL to store the glance-registry data, i.e. all of the image metadata. Therefore we need to create the initial database:

	# openstack-db --init --service glance
	
NOTE: If the above fails, you'll need to manually create the database...

	# openstack-db --drop --service glance
	# mysql -u root -p
	(Enter your 'mysql root' password)
	
	mysql> CREATE DATABASE glance;
	mysql> CREATE USER 'glance'@'localhost' IDENTIFIED BY 'glance';
	mysql> CREATE USER 'glance'@'%' IDENTIFIED BY 'glance';
	mysql> GRANT ALL ON glance.* TO 'glance'@'localhost';
	mysql> GRANT ALL ON glance.* TO 'glance'@'%';
	mysql> exit
	Bye
	
	# openstack-config --set /etc/glance/glance-api.conf DEFAULT sql_connection mysql://glance:glance@localhost/glance
	# openstack-config --set /etc/glance/glance-registry.conf DEFAULT sql_connection mysql://glance:glance@localhost/glance
	
	# service openstack-glance-api restart && service openstack-glance-registry restart
	# glance-manage db_sync

##**Integrating Glance with Keystone**

Before we use the Glance service, we need to configure it to speak to Keystone to manage authentication. We make heavy use of the openstack-config tool here for convenience although manually modifying the configuration files is also possible. We provide Glance with a username and password combination that has the 'admin' role, this is to check the validity of tokens provided to Glance.

Firstly, we create a separate tenant to house our 'service users', i.e. the credentials used by the individual services.

	# source ~/keystonerc_admin
	# keystone tenant-create --name services
	+-------------+----------------------------------+
	|   Property  |              Value               |
	+-------------+----------------------------------+
	| description |                                  |
	|   enabled   |               True               |
	|      id     | 44f64fb7e72a4d219d5f16b936c8bc25 |
	|     name    |             services             |
	+-------------+----------------------------------+
	
Next, create a user for Glance and attach it to the 'services' tenant and giving it the correct 'admin' role:

	# keystone user-create --name glance --pass glancepasswd
	+----------+----------------------------------+
	| Property |              Value               |
	+----------+----------------------------------+
	|  email   |                                  |
	| enabled  |               True               |
	|    id    | 46bdec9fe05b467099d6e260a280c0db |
	|   name   |              glance              |
	| tenantId |                                  |
	+----------+----------------------------------+
	
	# keystone user-role-add --user glance --role admin --tenant services
	
Now we have to associate 

	# openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
	# openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name services
	# openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_user glance
	# openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_password glancepasswd

	# openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
	# openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name services
	# openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_user glance
	# openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password glancepasswd

Note: One additional configuration option change that would usually need to be made is the 'auth_host' option in both /etc/glance/glance-api.conf and /etc/glance/glance-registry.conf, but as we're using Keystone on the *same* server as Glance we can ignore this option as the default behavior is to look at localhost.

We can now start and enable these services upon boot:

	# service openstack-glance-registry restart && chkconfig openstack-glance-registry on
	# service openstack-glance-api restart && chkconfig openstack-glance-api on

To complete the integration, a service and an associated end-point need to be created in Keystone:

	# source ~/keystonerc_admin
	
	# keystone service-create --name glance --type image --description "Glance Image Service"
	+-------------+----------------------------------+
	|   Property  |              Value               |
	+-------------+----------------------------------+
	| description |       Glance Image Service       |
	|      id     | 91a5530418ac477e9f7e3d8626e4092c |
	|     name    |              glance              |
	|     type    |              image               |
	+-------------+----------------------------------+

	# keystone endpoint-create --service_id 91a5530418ac477e9f7e3d8626e4092c \
		--publicurl http://192.168.122.101:9292 \
		--adminurl http://192.168.122.101:9292 \
		--internalurl http://192.168.122.101:9292
	+-------------+----------------------------------+
	|   Property  |              Value               |
	+-------------+----------------------------------+
	|   adminurl  |   http://192.168.122.101:9292    |
	|      id     | 714743a317c04252b872c3ba7a7eda58 |
	| internalurl |   http://192.168.122.101:9292    |
	|  publicurl  |   http://192.168.122.101:9292    |
	|    region   |            regionOne             |
	|  service_id | 91a5530418ac477e9f7e3d8626e4092c |
	+-------------+----------------------------------+

Note: There's no difference with the port numbers for the Glance service API as there's no specific admin differentiation.

To test the end-point, issue the following:

	# glance index

If you get an empty table it was successful, otherwise we may need to check the service is running and that the entries into keystone were accurate.

##**Adding an image to Glance**

As previously mentioned, images uploaded to Glance should be 're-initialised' or 'syspreped' so that any system-specific configuration is wiped away, this ensures that there are no conflicts between instances that are started. It's common practice to find pre-defined virtual machine images online that contain a base operating system and perhaps a set of packages for a particular purpose. The next few steps will allow you to take such an image and upload it into the Glance registry. 

Firstly, we need to get access to an image, if you're following the training course, get hold of the RHEL 6.4 Cloud template from your instructor (this is slightly different to the original template provided as it has cloud-init already installed, more to come later).

	(On your controller node)# yum install openssh-clients -y
	(On your hypervisor host)# scp /path/to/rhel64-cloud.qcow2 root@192.168.122.101:/root

Return back to your openstack-controller machine where you have your ssh session running. Let's verify that the disk image was copied across successfully and has the correct properties:

	# yum install qemu-img -y

	# qemu-img info /root/rhel64-cloud.qcow2
	image: rhel64-cloud.qcow2
	file format: qcow2
	virtual size: 10G (10737418240 bytes)
	disk size: 840M
	cluster_size: 65536

Note: If you've opted to use a disk-image you've already created outside of these labs, I strongly advise that you use 'virt-sysprep' to prepare the machine before importing. Instructions are available in Lab #2.

Next we can create a new image within Glance and import its contents, it may take a few minutes to copy the data. The 'admin' account should be used to upload the image, we'll then make it public to every tenant, i.e. everybody:

	# source ~/keystonerc_admin

	# glance image-create --name "Red Hat Enterprise Linux 6.4" --is-public true \
		--disk-format qcow2 --container-format bare \
		--file /root/rhel64-cloud.qcow2
	+------------------+--------------------------------------+
	| Property         | Value                                |
	+------------------+--------------------------------------+
	| checksum         | ace8786fb3216bcc16e47ffdf1d53791     |
	| container_format | bare                                 |
	| created_at       | 2013-06-10T11:08:06                  |
	| deleted          | False                                |
	| deleted_at       | None                                 |
	| disk_format      | qcow2                                |
	| id               | 008b9660-d700-48c9-908a-f9f3170e6405 |
	| is_public        | True                                 |
	| min_disk         | 0                                    |
	| min_ram          | 0                                    |
	| name             | Red Hat Enterprise Linux 6.4         |
	| owner            | 9a34e557191f4e2db8e25aabf472f767     |
	| protected        | False                                |
	| size             | 880607232                            |
	| status           | active                               |
	| updated_at       | 2013-06-10T11:08:19                  |
	+------------------+--------------------------------------+


The container format is 'bare' because it doesn't require any additional images such as a kernel or initrd, it's completely self-contained. The 'is-public' option allows any user within the tenant (project) to use the image rather than locking it down for the specific user uploading the image.

We'll use this image for deploying instances on OpenStack in the next few labs.


#**Lab 5: Installation and configuration of Cinder (Volume Service)**

**Prerequisites:**
* Keystone installed and configured as per Lab 3

##**Introduction**

Cinder is OpenStack's volume service, it's responsible for managing persistent block storage, i.e. the creation of a block device, it's lifecycle, connections to instances and it's eventual deletion. Block storage is a requirement in OpenStack for many reasons, firstly persistence but also for performance scenarios, e.g. access to data backed by tiered storage. Cinder supports many different back-ends in which it can connect to and manage storage for OpenStack, including HP's LeftHand, EMC, IBM, Ceph and NetApp, although it does support a basic Linux storage model, based on iSCSI. Cinder was once part of Nova (the OpenStack Compute service, which we'll come onto later on in this guide) and was known as nova-volume; it's since been divorced from Nova in order to allow each distinct component to evolve independently. 

##**Installing Cinder**

We'll install Cinder on our cloud controller machine, i.e. 'openstack-controller', we can place Cinder anywhere in the cluster but for convenience of the labs we'll keep the core services on this node. Before we install the components, we need to create a new user, just like the previous lab to authenticate user tokens:

	# source ~/keystonerc_admin
	# keystone user-create --name cinder --pass cinderpasswd
	+----------+----------------------------------+
	| Property |              Value               |
	+----------+----------------------------------+
	|  email   |                                  |
	| enabled  |               True               |
	|    id    | 063016ac322a45ebb231d4bd5f03cd4d |
	|   name   |              cinder              |
	| tenantId |                                  |
	+----------+----------------------------------+
	
Add this user into the correct 'services' tenant and give it the 'admin' role:
	
	# keystone user-role-add --user cinder --role admin --tenant services
		
Next, install the Cinder components:

	# yum install openstack-cinder -y

##**Configuring Cinder**

Cinder uses a MySQL database to hold information about the volumes that it's managing, we'll simply add this database into the already existant MySQL deployment:

	# openstack-db --init --service cinder

As with all other OpenStack services, Cinder uses Keystone for authentication, we'll need to configure this to communicate with Keystone running on openstack-controller. We can use the handy 'openstack-config' tool to make these changes for us:

	# openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
	# openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name services
	# openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_user cinder
	# openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_password cinderpasswd

At the start of this guide we created an AMQP/qpid server for component communication, Cinder is one of those components that makes use of this message queue. We will need to modify our Cinder configuration to point to the server running on openstack-controller:

	# openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_hostname 192.168.122.101
	# openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_port 5672

##**Preparing storage for Cinder**

The easiest way to get started with Cinder volumes is to just use it's basic in-built (iSCSI-based) volume service; in production you'd likely connect out to an external SAN however this guide will explain how to configure the basic service. For this you need to create a standard LVM volume group named 'cinder-volumes', which Cinder will carve up into individual logical volumes to present as block devices to the compute instances. The initial virtual machines were created with 30GB storage, so we've got enough to create a local VG.

Warning: The instructions below are not recommended for any form of production environment, they provide a mechanism of creating the required volume group but should not be relied on. An additional disk of partition should be used instead...

	# dd if=/dev/zero of=/cinder-volumes bs=1 count=0 seek=5G
	# losetup -fv /cinder-volumes
	Loop device is /dev/loop0

	# vgcreate cinder-volumes /dev/loop0
	No physical volume label read from /dev/loop0
 	Physical volume "/dev/loop0" successfully created
	Volume group "cinder-volumes" successfully created

	# vgdisplay cinder-volumes
	--- Volume group ---
	VG Name               cinder-volumes
	System ID             
	Format                lvm2
	Metadata Areas        1
	Metadata Sequence No  1
	VG Access             read/write
	VG Status             resizable
	MAX LV                0
	Cur LV                0
	Open LV               0
	Max PV                0
	Cur PV                1
	Act PV                1
	VG Size               5.00 GiB
	PE Size               4.00 MiB
	Total PE              5119
	Alloc PE / Size       0 / 0   
	Free  PE / Size       5119 / 20.00 GiB
	VG UUID               JKYl9k-DlQb-HT8l-xyUv-9mKA-Ebhe-82YeUL

All logical volumes created by Cinder will be made available via tgtd, the iSCSI Target Daemon. Each volume has it's own configuration which sits inside of '/etc/cinder/volumes/' and therefore we need to ensure that tgtd is aware of it:

	# echo "include /etc/cinder/volumes/*" >> /etc/tgt/targets.conf
	# service tgtd start && chkconfig tgtd on

Once this is complete, we can start Cinder:

	# service openstack-cinder-api start
	# service openstack-cinder-scheduler start
	# service openstack-cinder-volume start

Don't forget to enable these services on:

	# chkconfig openstack-cinder-api on
	# chkconfig openstack-cinder-scheduler on
	# chkconfig openstack-cinder-volume on

##**Integrating Cinder with Keystone**

Finally, endpoints for the Cinder service need to be added to Keystone:

	# keystone service-create --name cinder --type volume --description "Cinder Volume Service"
	+-------------+----------------------------------+
	|   Property  |              Value               |
	+-------------+----------------------------------+
	| description |      Cinder Volume Service       |
	|      id     | 94ed0a651b4342e2a2c25c00c2b271d8 |
	|     name    |              cinder              |
	|     type    |              volume              |
	+-------------+----------------------------------+

And then the endpoint, not forgetting to use the id from the previous command, *NOT* the one you see above in this guide.

	# keystone endpoint-create --service_id 94ed0a651b4342e2a2c25c00c2b271d8 \
		--publicurl "http://192.168.122.101:8776/v1/\$(tenant_id)s" \
		--adminurl "http://192.168.122.101:8776/v1/\$(tenant_id)s" \
		--internalurl "http://192.168.122.101:8776/v1/\$(tenant_id)s"
	+-------------+----------------------------------------------+
	|   Property  |                    Value                     |
	+-------------+----------------------------------------------+
	|   adminurl  | http://192.168.122.101:8776/v1/$(tenant_id)s |
	|      id     |       002bdb25d74f45fe9a202f0fbbb3c97e       |
	| internalurl | http://192.168.122.101:8776/v1/$(tenant_id)s |
	|  publicurl  | http://192.168.122.101:8776/v1/$(tenant_id)s |
	|    region   |                  regionOne                   |
	|  service_id |       94ed0a651b4342e2a2c25c00c2b271d8       |
	+-------------+----------------------------------------------+

Note: We were required to enter 'tenant_id' in the URL string as this gets automatically substituted by the client that's interacting with the API, that way we're only able to see/configure the volumes within that users tenant/project.

##**Testing Cinder**

Let's test our Cinder configuration, making sure that it can create a volume, note that you'll need to be authenticated with Keystone for this to work:

	# cinder create --display-name Test 1
	+---------------------+--------------------------------------+
	|       Property      |                Value                 |
	+---------------------+--------------------------------------+
	|     attachments     |                  []                  |
	|  availability_zone  |                 nova                 |
	|      created_at     |      2013-03-30T18:34:15.049367      |
	| display_description |                 None                 |
	|     display_name    |                 Test                 |
	|          id         | d1907853-68e5-45e7-aa86-23b52a833258 |
	|       metadata      |                  {}                  |
	|         size        |                  1                   |
	|     snapshot_id     |                 None                 |
	|        status       |               creating               |
	|     volume_type     |                 None                 |
	+---------------------+--------------------------------------+

	# lvs | grep cinder-volumes
	volume-d1907853-68e5-45e7-aa86-23b52a833258 cinder-volumes -wi-ao---  1.00g

	# cinder delete d1907853-68e5-45e7-aa86-23b52a833258

Cinder logs itself at /var/log/cinder/*.log, so if you have any problems trying to create or delete any volumes it might be worth watching these logfiles. We'll be using Cinder in later labs to attach volumes to instances-

	# tail -f /var/log/cinder/*.log
	(Ctrl-C to quit)


#**Lab 6: Installation and configuration of Quantum (Networking Service)**

**Prerequisites:**
* Keystone installed and configured as per Lab 3
* Two network interfaces attached to both OpenStack nodes, if using virtual machines ensure that eth0 is NAT'd to the rest of the world and eth1 is on a private/isolated vSwitch.

##**Introduction**

Quantum is OpenStack's Networking service, although it's important to realise that the name 'Quantum' will likely be replaced with just 'OpenStack Networking', apparently down to a trademark infringement. The training will continue to use the Quantum terminology for now as documentation and commands still explicitly use 'quantum'. 

Quantum provides an abstract virtual networking service, enabling administrators and end-users to manage virtual networks for their instances on-top of OpenStack, i.e. Networking-as-a-Service. Quantum simply provides an API for self-service and management but relies on underlying technologies for the actual implementation via Quantum-plugins. This training makes use of Open vSwitch, but there are many other plugins available upstream such as Nicira NVP, Cisco UCS, Brocade etc. Quantum allows cloud-tenants to create rich networking topologies in an 'over-cloud' including advanced networking services, e.g. LBaaS, VPNaaS and Firewall-aaS. 

Quantum replaces the initial nova-network component that provided networking to instances in OpenStack prior to Folsom, it overcomes limitations such as lack of true isolation (unless implementing VLANs) and networks being down to the cloud-provider to manage. It vastly enhances the ability to provide networking and places the control in the hands of the users. This lab will get you to implement a Quantum networking infrastructure as a pre-requisite to starting our first instances, we'll configure underlying networking devices and attach them into Open vSwitch for use within Quantum.

##**Preparing the Cloud Controller**

We're going to be using Open vSwitch to provide the underlying networking infrastructure, this then attaches into Quantum via a plugin so that Quantum can call out to Open vSwitch to actually implement the networks required. When I say networks, what I really mean is tenant-networks, i.e. the networks virtually created by either the administrators of the cloud or the end-users. 

Open vSwitch relies on 'OVS Bridges' to attach both physical network cards and virtual machine's NICs to, not to be confused with traditional Linux bridges. It uses 'br-int' as the integration bridge, it's where all virtual network cards for the respective instances running on that machine get attached into, this bridge is then linked into a physical adaptor to provide a bridge out into the real world, enabling connectivity between machines; for example, inter-instance communication or internet access. 

In addition to 'br-int' being used for virtual machine mapping, any additional agents also get linked into this bridge, e.g. for DHCP or L3 routing, anything that needs to communicate with instances needs to route through this bridge. For external access, 'br-ex' is used to define a network device to provide external access to (and from) our instances.

In this lab, we'll use the cloud controller to provide all of the Quantum services, plus act as the 'networking' node, i.e. the one that provides DHCP and external access for our instances. Therefore we need to establish a number of OVS bridges:

	# ssh root@openstack-controller
	# yum install openstack-quantum openvswitch openstack-quantum-openvswitch -y
	
Add the integration bridge:

	# service openvswitch start
	# ovs-vsctl add-br br-int

Add the bridge that maps OVS to the real world, note that we're using 'eth1' here as this network will only be used for inter-instance traffic...

	# cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
	DEVICE=eth1
	BOOTPROTO=static
	NM_CONTROLLED=no
	ONBOOT=yes
	TYPE=Ethernet
	EOF
	
	# ifup eth1
	# ovs-vsctl add-br br-eth1
	# ovs-vsctl add-port br-eth1 eth1
	# ovs-vsctl show
	54042c1d-3fd5-4ddd-a70c-170b0ac7bf8e
    Bridge "br-eth1"
        Port "eth1"
            Interface "eth1"
        Port "br-eth1"
            Interface "br-eth1"
                type: internal
    Bridge br-int
        Port br-int
            Interface br-int
                type: internal
    ovs_version: "1.9.0"
    
Next, we need to create an external network bridge. This is a little bit tricky as we're only providing two network interfaces to our machines, for this to come up on-boot and not break our SSH connectivity we need to make this 'device' persistent:

	# cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-br-ex
	DEVICE=br-ex
	BOOTPROTO=static
	ONBOOT=yes
	IPADDR=192.168.122.101
	NETMASK=255.255.255.0
	GATEWAY=192.168.122.1
	EOF
	
We can therefore unconfigure our eth0 device, as we'll be attaching this to the OVS bridge we create shortly:

	# cp /etc/sysconfig/network-scripts/ifcfg-eth0 /root/ifcfg-eth0-backup
	# cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
	DEVICE=eth0
	TYPE=Ethernet
	ONBOOT="yes"
	NM_CONTROLLED=no
	BOOTPROTO=static
	EOF
	
Finally, create the 'br-ex' external bridge and attach our eth0 device into it:

	# ovs-vsctl add-br br-ex
	# ovs-vsctl add-port br-ex eth0
	
Note: This will hang at this point as it hasn't brought 'br-ex' up. You'll need to access the console to run the following:

	(In console)
	# service network restart
	Shutting down interface eth0:                              [  OK  ]
	Shutting down interface eth1:                              [  OK  ]
	Shutting down loopback interface:                          [  OK  ]
	Bringing up loopback interface:                            [  OK  ]
	Bringing up interface br-ex:                               [  OK  ]
	Bringing up interface eth0:                                [  OK  ]
	Bringing up interface eth1:                                [  OK  ]
	
You should now be able to return to your SSH session.
	
To confirm that everything is as expected, you can check the output of 'ovs-vsctl show':

	# ovs-vsctl show
	54042c1d-3fd5-4ddd-a70c-170b0ac7bf8e
    Bridge "br-eth1"
        Port "eth1"
            Interface "eth1"
        Port "br-eth1"
            Interface "br-eth1"
                type: internal
    Bridge br-ex
        Port br-ex
            Interface br-ex
                type: internal
        Port "eth0"
            Interface "eth0"
    Bridge br-int
        Port br-int
            Interface br-int
                type: internal
    ovs_version: "1.9.0"

Next we need to configure Quantum itself, there are a number of configuration files we need to setup:

	# quantum-server-setup
	(Use openvswitch)
	
Let Quantum know that we're using Open vSwitch as our plugin and that we want to be able to use overlapping IPs, i.e. multiple tenants can have the same subnet ranges:

	# openstack-config --set /etc/quantum/quantum.conf DEFAULT core_plugin quantum.plugins.openvswitch.ovs_quantum_plugin.OVSQuantumPluginV2
	# openstack-config --set /etc/quantum/quantum.conf DEFAULT ovs_use_veth True
	# openstack-config --set /etc/quantum/quantum.conf DEFAULT allow_overlapping_ips True
	
Quantum uses qpid for communication between the server and the agents, we already have one configured:

	# openstack-config --set /etc/quantum/quantum.conf DEFAULT rpc_backend quantum.openstack.common.rpc.impl_qpid
	# openstack-config --set /etc/quantum/quantum.conf DEFAULT qpid_hostname 192.168.122.101
	# openstack-config --set /etc/quantum/quantum.conf DEFAULT qpid_port 5672
	# openstack-config --set /etc/quantum/quantum.conf AGENT root_helper sudo quantum-rootwrap /etc/quantum/rootwrap.conf
	
We'll set Keystone up later on, but we need to make entries into quantum.conf to represent these:

	# openstack-config --set /etc/quantum/quantum.conf DEFAULT auth_strategy keystone
	# openstack-config --set /etc/quantum/quantum.conf keystone_authtoken auth_host 192.168.122.101
	# openstack-config --set /etc/quantum/quantum.conf keystone_authtoken admin_tenant_name services
	# openstack-config --set /etc/quantum/quantum.conf keystone_authtoken admin_user quantum
	# openstack-config --set /etc/quantum/quantum.conf keystone_authtoken admin_password quantumpasswd
	
Next, configure the plugin itself. If the symlink wasn't created for you, you'll need to set it up:

	# ll /etc/quantum/plugin.ini
	lrwxrwxrwx 1 root root 55 Jun 12 17:22 plugin.ini -> /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
	
If it doesn't exist:

	# ln -s /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini /etc/quantum/plugin.ini
	
Then, make the necessary modifications, first set the database:

	# openstack-config --set /etc/quantum/plugin.ini DATABASE sql_connection mysql://quantum:quantum@192.168.122.101/ovs_quantum
	
Next, configure OVS to use VLAN's to isolate the tenant networks from each other. Note that we're using VLANs here because RHEL currently doesn't support network tunnelling, e.g. GRE/VXLAN. We also configure a set of VLAN tag ranges and crucially MAP our br-eth1 device which we created previously to a 'physnet' network provider.

	# openstack-config --set /etc/quantum/plugin.ini OVS tenant_network_type vlan
	# openstack-config --set /etc/quantum/plugin.ini OVS network_vlan_ranges physnet1:1000:2999
	# openstack-config --set /etc/quantum/plugin.ini OVS bridge_mappings physnet1:br-eth1
	
Ensure that the Firewall options are configured correctly, i.e. to use iptables to provide security for our instances:

	# openstack-config --set /etc/quantum/plugin.ini SECURITYGROUP firewall_driver quantum.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
	
I mentioned previously that we configure Quantum to provide a number of additional agents to provide functionality such as DHCP and L3-routing to external networks, these need to be configured also.

We configure the DHCP agent to use OVS:

	# openstack-config --set /etc/quantum/dhcp_agent.ini DEFAULT interface_driver quantum.agent.linux.interface.OVSInterfaceDriver
	
To handle all routers, regardless of whether they have/require external connectivity:

	# openstack-config --set /etc/quantum/dhcp_agent.ini DEFAULT handle_internal_only_routers True
	
Configure the external bridge network:

	# openstack-config --set /etc/quantum/dhcp_agent.ini DEFAULT external_network_bridge br-ex
	
Configure the agent to allow for namespaces, i.e. to use overlapping IPs:

	# openstack-config --set /etc/quantum/dhcp_agent.ini DEFAULT use_namespaces True
	
As this configuration file is identical to the L3 one, we can simply copy them:

	# cp /etc/quantum/dhcp_agent.ini /etc/quantum/l3_agent.ini
	(y)
	
Configure Keystone to provide authentication and an endpoint for Quantum:

	# source keystonerc_admin
	# keystone user-create --name quantum --pass quantumpasswd
	# keystone user-role-add --user quantum --role admin --tenant services
	
	# keystone service-create --name quantum --type network --description "Quantum Network Service" 
	+-------------+----------------------------------+
	| description |      Quantum Network Service     |
	|      id     | c12b2784b0734cdd8fafd8c8654deb1d |
	|     name    |             quantum              |
	|     type    |             network              |
	+-------------+----------------------------------+
	
	# keystone endpoint-create --service_id c12b2784b0734cdd8fafd8c8654deb1d \
		--publicurl "http://192.168.122.101:9696" \
		--adminurl "http://192.168.122.101:9696" \
		--internalurl "http://192.168.122.101:9696"
	+-------------+----------------------------------+
	|   Property  |              Value               |
	+-------------+----------------------------------+
	|   adminurl  |   http://192.168.122.101:9696    |
	|      id     | 714743a317c04252b872c3ba7a7eda58 |
	| internalurl |   http://192.168.122.101:9696    |
	|  publicurl  |   http://192.168.122.101:9696    |
	|    region   |            regionOne             |
	|  service_id | c12b2784b0734cdd8fafd8c8654deb1d |
	+-------------+----------------------------------+
	
Start the services and configure them to come up on boot:

	# chkconfig openvswitch on
	# service quantum-server start && chkconfig quantum-server on
	# service quantum-l3-agent start && chkconfig quantum-l3-agent on
	# service quantum-dhcp-agent start && chkconfig quantum-dhcp-agent on
	# service quantum-openvswitch-agent start && chkconfig quantum-openvswitch-agent on
	# service quantum-ovs-cleanup start && chkconfig quantum-ovs-cleanup on
	
##**RHEL 6.4 Bug Workaround**

Unfortunately there's a current bug with RHEL 6.4, if VLANs are being used to isolate tenant networks the VLAN tags get dropped when received by other nodes sitting on the network. This can be worked around by creating a phantom network interface with an associated VLAN tag, that way it ensures that when a packet is received with a VLAN tag (including over the OVS bridges) they are honoured. A quick work-around is as follows:

	(If you're not already connected to openstack-controller)
	# ssh root@openstack-controller
	
	# cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth1.200	
	DEVICE=eth1.200
	ONBOOT=yes
	TYPE=Ethernet
	VLAN=yes
	EOF
	
	# ifup eth1.200
	
##**Preparing our Compute Node**

As this is the first time we're using our compute node, follow the initial steps to ensure we have correct package access:

	# subscription-manager register
	(Enter your Red Hat Network credentials)

Next you need to subscribe your system to both a Red Hat Enterprise Linux pool and the OpenStack Enterprise pools-

	# subscription-manager list --available
	(Discover pool ID's for both)

	# subscription-manager subscribe --pool <RHEL Pool> --pool <OpenStack Pool>

We need to enable the OpenStack repositories next:

	# yum install yum-utils -y
	# yum-config-manager --enable rhel-server-ost-6-3-rpms --setopt="rhel-server-ost-6-3-rpms.priority=1"
	
Install the Red Hat OpenStack-specific Kernel and associated packages, this is down to the standard Red Hat kernel not being shipped with namespace support. Please ask your instructor for these files, if you're not following an instructor-led training course then please ask your Red Hat representative.

	# yum localinstall /path/to/rpms/*.rpm -y	
	# yum update -y
	# reboot

Thankfully, the Open vSwitch configuration for the compute node is a lot simpler! We can copy the configuration files from the controller:

	(After the machine has rebooted)
	# ssh root@openstack-compute1
	
	# scp root@openstack-controller:/etc/quantum/quantum.conf /etc/quantum/quantum.conf
	# scp root@openstack-controller:/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
	# ln -s /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini /etc/quantum/plugin.ini
	
Create the bridges like we did before, although this time we don't have to worry about eth0 as we're not configuring an external bridge... the l3-agent on the controller node does the routing for us, we just need to give our br-int access to eth1:

	# yum install openstack-quantum -y
	
	# cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
	DEVICE=eth1
	BOOTPROTO=static
	NM_CONTROLLED=no
	ONBOOT=yes
	TYPE=Ethernet
	EOF
	
	# ifup eth1
	# ovs-vsctl add-br br-int
	# ovs-vsctl add-br br-eth1
	# ovs-vsctl add-port br-eth1 eth1
	
	# ovs-vsctl show
	cf94f69d-737d-441f-b803-d3615de877da
    Bridge "br-eth1"
        Port "br-eth1"
            Interface "br-eth1"
                type: internal
        Port "eth1"
            Interface "eth1"
    Bridge br-int
        Port br-int
            Interface br-int
                type: internal
    ovs_version: "1.9.0"
	
Make sure the correct services are started and enabled:

	# service quantum-openvswitch-agent start && chkconfig quantum-openvswitch-agent on
	# service quantum-ovs-cleanup start && chkconfig quantum-ovs-cleanup on
	
As with the openstack-controller, we need to workaround the current VLAN bug:

	# cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth1.200	
	DEVICE=eth1.200
	ONBOOT=yes
	TYPE=Ethernet
	VLAN=yes
	EOF
	
	# ifup eth1.200

#**Lab 7: Installation and configuration of Nova (Compute Service)**

**Prerequisites:**
* Keystone installed and configured as per Lab 3

##**Introduction**

Nova is OpenStack's compute service, it's responsible for providing and scheduling compute resource for OpenStack instances. It's undoubtably the most important part of the OpenStack project. It was designed to massively scale horizontally to cater for the largest clouds. Nova supports a wide variety of hardware and software platforms, including the most popular hypervisors such as KVM, Xen, Hyper-V and VMware ESX, turning traditional virtualisation environments into cloud resource pools. Nova has many different individual components, each of which are responsible for a specific task, examples include a compute driver which is responsible for providing resource to the cloud, a scheduler to respond to and allocate requests from cloud consumers and a network layer which provides inward and outward network traffic to compute instances.

Nova is quite fragmented in its architecture, the scheduler as an example typically sits on a separate machine to the compute nodes, where only the compute and network components exist. As with other components, a message bus exists between all the components allowing the distribution to be completely open and as a result can drastically scale. 

The lab will walk you through deploying Nova across the cluster, utilising our 'cloud controller' (openstack-controller) to provide the API and scheduler services and the remaining two virtual machines to provide compute resource (with associated network component). It will also show you how to manage the individual Nova services and integrate with the rest of the stack.

Estimated completion time: 1 hour

##**Preparing the Cloud Controller**

We need to deploy the Nova components on our first node that will provide the API and the scheduler services and will be the endpoint for Nova in our environment. It's important to note that typically the Nova configuration between cloud controller nodes and compute nodes is actually almost identical, it's the Nova services that are started on a particular node that define its responsibilities. Therefore it may seem strange why we're configuring Nova on openstack-controller!

	(If you're not already connected to openstack-controller)
	# ssh root@openstack-controller
	# source ~/keystonerc_admin

	# yum install openstack-nova -y
	# openstack-db --init --service nova --password <password>
	
	# keystone user-create --name nova --pass novapasswd
	+----------+----------------------------------+
	| Property |              Value               |
	+----------+----------------------------------+
	|  email   |                                  |
	| enabled  |               True               |
	|    id    | 4981852a8b654e8ea52fee94fcf65dd2 |
	|   name   |               nova               |
	| tenantId |                                  |
	+----------+----------------------------------+
	
Add this user into the correct 'services' tenant and give it the 'admin' role; you can use 'keystone tenant-list' or 'keystone role-list' to get the required id's:
	
	# keystone user-role-add --user nova --role admin --tenant services

A few necessary changes to the Nova configuration file are required in order to establish integration with other components that we've already setup. There are over 570 configuration options within Nova at the time of writing this so it gets extremely difficult to troubleshoot using the configuration file. Many of the options are commented out but it does provide you with every option possible. For ease of deployment, below is a basic Nova configuration file which is tailored to the environment that we've been creating.

Firstly, move the original nova.conf file to somewhere safe so we've always got a backup:

	# mv /etc/nova/nova.conf ~/nova.conf.original

Then copy the following code into /etc/nova/nova.conf:

	[DEFAULT]
	logdir = /var/log/nova
	state_path = /var/lib/nova
	lock_path = /var/lib/nova/tmp
	volumes_dir = /etc/nova/volumes
	dhcpbridge = /usr/bin/nova-dhcpbridge
	dhcpbridge_flagfile = /etc/nova/nova.conf
	force_dhcp_release = True
	injected_network_template = /usr/share/nova/interfaces.template
	libvirt_nonblocking = True
	libvirt_inject_partition = -1
	libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
	iscsi_helper = tgtadm
	sql_connection = mysql://nova:nova@192.168.122.101/nova
	compute_driver = libvirt.LibvirtDriver
	libvirt_type=qemu
	rpc_backend = nova.openstack.common.rpc.impl_qpid
	rootwrap_config = /etc/nova/rootwrap.conf
	auth_strategy = keystone
	firewall_driver=nova.virt.firewall.NoopFirewallDriver

	volume_api_class = nova.volume.cinder.API
	enabled_apis = ec2,osapi_compute,metadata
	my_ip=192.168.122.101
	qpid_hostname=192.168.122.101
	qpid_port=5672

	glance_host=192.168.122.101
	network_api_class = nova.network.quantumv2.api.API
	quantum_admin_username = quantum
	quantum_admin_password = quantumpasswd
	quantum_admin_auth_url = http://192.168.122.101:35357/v2.0/
	quantum_auth_strategy = keystone
	quantum_admin_tenant_name = services
	quantum_url = http://192.168.122.101:9696/
	security_group_api = quantum

	[keystone_authtoken]
	admin_tenant_name = services
	admin_user = nova
	admin_password = novapasswd
	auth_host = 192.168.122.101
	auth_port = 35357
	auth_protocol = http
	signing_dirname = /tmp/keystone-signing-nova

What this configuration is describing is as follows-

* The MySQL database (which holds the instance data) is located on openstack-controller
* We want to use Libvirt for the Compute, but qemu based emulation (In physical you would use 'kvm' here)
* We are not using nova-based firewalling, this is taken care of by Quantum
* We are using qpid as the backend messaging broker (and it sits on openstack-controller)
* Cinder is the volume manager for providing persistent storage
* Glance is providing the images and it sits on 192.168.122.101
* The machine's IP address is 192.168.122.101 (openstack-controller)
* We are using Quantum to provide network access
* And we're using Keystone for authentication.

Note: Remember to change the keystone admin_password entry and the MySQL password to reflect your configuration.	

Just to make sure the file has been created properly:

	# chown root:nova /etc/nova/nova.conf
	# restorecon /etc/nova/nova.conf
	# chmod 640 /etc/nova/nova.conf

That configuration should be enough for the cloud controller machine, we can then start the necessary services on this machine:

	# service openstack-nova-api start
	# service openstack-nova-scheduler start
	# service openstack-nova-conductor start

	# chkconfig openstack-nova-api on
	# chkconfig openstack-nova-scheduler on
	# chkconfig openstack-nova-conductor on
	
Note: The conductor service is brand-new to Grizzly, it takes away the ability for the compute nodes to update the database, providing security and isolation from instances and the underlying database. The conductor can theoretically sit on any node, it simply takes data from the message bus, but it can sit on the controller node for the purpose of this lab.

##**Preparing the Compute Nodes**

We configure Nova on the compute node but literally only to provide compute resources to the pool:

	# ssh root@openstack-compute1

	# yum install openstack-nova -y
	# yum install python-cinderclient -y

Also, as this machine will provide resource, we need to ensure that libvirt is installed-

	# yum install libvirt -y
	# chkconfig libvirtd on && service libvirtd start

	# scp root@openstack-controller:/etc/nova/nova.conf /etc/nova/nova.conf
	# chown root:nova /etc/nova/nova.conf
	# restorecon /etc/nova/nova.conf
	# chmod 640 /etc/nova/nova.conf

Remember that the nova.conf that was on openstack-controller was slightly configured specifically for openstack-controller, we should make a few changes so that it fits with node3's configuration:

	# sed -i 's/my_ip=.*/my_ip=192.168.122.102/g' /etc/nova/nova.conf

Note: If your compute node is not at '192.168.122.102, make the required change in the above sed command, or just manually edit the /etc/nova/nova.conf file.

We can now start the required services on this node, for now we only need compute...

	# service openstack-nova-compute start
	# chkconfig openstack-nova-compute on

We're now finished with openstack-compute1 for now, we need to return to our cloud controller (openstack-controller) and setup the keystone service and endpoints:

	# ssh root@openstack-controller
	# source keystonerc_admin

	# keystone service-create --name nova --type compute --description "Nova Compute Service"
	+-------------+----------------------------------+
	|   Property  |              Value               |
	+-------------+----------------------------------+
	| description |       Nova Compute Service       |
	|      id     | 59fdd4afc25d4e62aa7494ffcf05a78f |
	|     name    |               nova               |
	|     type    |             compute              |
	+-------------+----------------------------------+

	# keystone endpoint-create --service_id 59fdd4afc25d4e62aa7494ffcf05a78f \
		--publicurl "http://192.168.122.101:8774/v1.1/\$(tenant_id)s" \
		--adminurl "http://192.168.122.101:8774/v1.1/\$(tenant_id)s" \
		--internalurl "http://192.168.122.101:8774/v1.1/\$(tenant_id)s"
	+-------------+------------------------------------------------+
	|   Property  |                     Value                      |
	+-------------+------------------------------------------------+
	|   adminurl  | http://192.168.122.101:8774/v1.1/$(tenant_id)s |
	|      id     |        44d3e0c6bec74ff39bea02b929aec3af        |
	| internalurl | http://192.168.122.101:8774/v1.1/$(tenant_id)s |
	|  publicurl  | http://192.168.122.101:8774/v1.1/$(tenant_id)s |
	|    region   |                   regionOne                    |
	|  service_id |        59fdd4afc25d4e62aa7494ffcf05a78f        |
	+-------------+------------------------------------------------+

Next, let's make sure that our integration into other components is working correctly. We can use 'nova-manage' to provide us with statistics and monitoring for Nova:

	# nova-manage service list
	Binary           Host                        Zone             Status     State Updated_At
	nova-scheduler   openstack-controller        internal         enabled    :-)   2013-06-09 00:13:17
	nova-compute     openstack-compute1        	 nova             enabled    :-)   2013-06-09 00:13:10
	nova-conductor   openstack-controller        internal         enabled    :-)   2013-06-09 00:13:17

We can see that nova-scheduler and nova-conductor is running on openstack-openstack-controller (where nova-api also runs, but isn't shown here) and nova-compute is running on openstack-openstack-compute1. This is all shared via AMQP/qpid. To test integration with Glance, for example:

	# nova image-list
	+--------------------------------------+------------------------------+--------+--------+
	| ID                                   | Name                         | Status | Server |
	+--------------------------------------+------------------------------+--------+--------+
	| af094839-814e-4b76-99c4-9470a8b91903 | Red Hat Enterprise Linux 6.4 | ACTIVE |        |
	+--------------------------------------+------------------------------+--------+--------+

We could of course, test Cinder integration but there's currently no volumes specified. If you're really wanting to test this, follow these instructions, note that you can carry out OpenStack tasks from any node that you have the rc file from:

	# source keystonerc_user
	# cinder create --display-name Test 2
	+---------------------+--------------------------------------+
	|       Property      |                Value                 |
	+---------------------+--------------------------------------+
	|     attachments     |                  []                  |
	|  availability_zone  |                 nova                 |
	|      created_at     |      2013-03-31T11:03:13.092670      |
	| display_description |                 None                 |
	|     display_name    |                 Test                 |
	|          id         | eeb4d74e-5794-426c-b71d-24f1f17eaba5 |
	|       metadata      |                  {}                  |
	|         size        |                  2                   |
	|     snapshot_id     |                 None                 |
	|        status       |               creating               |
	|     volume_type     |                 None                 |
	+---------------------+--------------------------------------+

	# nova volume-list
	+--------------------------------------+-----------+--------------+------+-------------+-------------+
	| ID                                   | Status    | Display Name | Size | Volume Type | Attached to |
	+--------------------------------------+-----------+--------------+------+-------------+-------------+
	| eeb4d74e-5794-426c-b71d-24f1f17eaba5 | available | Test         | 2    | None        |             |
	+--------------------------------------+-----------+--------------+------+-------------+-------------+

	# nova volume-delete eeb4d74e-5794-426c-b71d-24f1f17eaba5

Warning: If you've rebooted your Cinder node, it's likely that the above will fail. The mechanism we used for creating the volume-group is a temporary workaround. Please re-visit the lab to re-setup the volume group and restart the cinder services and re-attempt the above.

Note: One of the most common problems with services being visible but not in a 'happy' state is time inconsistencies. If you're experiencing issues please confirm the date/time first!

If you watch the nova logs on one of the compute nodes, you'll see the nodes checking in and updating their available resource for the scheduler...

	# tail -n5 /var/log/nova/compute.log 
	2013-06-31 13:06:10 1836 AUDIT nova.compute.resource_tracker [-] Free ram (MB): 1460
	2013-06-31 13:06:10 1836 AUDIT nova.compute.resource_tracker [-] Free disk (GB): 27
	2013-06-31 13:06:10 1836 AUDIT nova.compute.resource_tracker [-] Free VCPUS: 2
	2013-06-31 13:06:10 1836 INFO nova.compute.resource_tracker [-] Compute_service record updated for openstack-compute1 
	2013-06-31 13:06:10 1836 INFO nova.compute.manager [-] Updating host status

Finally, we need to configure our networks. We first create an external network which is owned by the 'services' tenant, this is the network that will be used to provide external connectivity to our instances. It's prudent to create this via the command-line:

First, get the tenant-id for the 'services' tenant:

	# source /root/keystonerc_admin
	# keystone tenant-list | grep services | awk '{print $2;}'
	aec5e4f4e53144fb828c22e77b1e620a
	
Then create the network with Quantum:

	# quantum net-create --tenant-id aec5e4f4e53144fb828c22e77b1e620a ext --router:external=True
	Created a new network:
	+---------------------------+--------------------------------------+
	| Field                     | Value                                |
	+---------------------------+--------------------------------------+
	| admin_state_up            | True                                 |
	| id                        | 7382ead9-faba-405a-a78f-404c236c9334 |
	| name                      | ext                                  |
	| provider:network_type     | vlan                                 |
	| provider:physical_network | physnet1                             |
	| provider:segmentation_id  | 1000                                 |
	| router:external           | True                                 |
	| shared                    | False                                |
	| status                    | ACTIVE                               |
	| subnets                   |                                      |
	| tenant_id                 | aec5e4f4e53144fb828c22e77b1e620a     |
	+---------------------------+--------------------------------------+
	
Note: The provider details have been placed in there for us, it knows we're using VLANs to isolate our tenant networks and it knows the physical network (physnet1) is mapped to eth1.

Next, create a subnet for this network, note that this corresponds to our libvirt network (192.168.122.0/24), note that if you're not using these network ranges/gateway, change as appropriate:

	# quantum subnet-create --tenant-id aec5e4f4e53144fb828c22e77b1e620a ext 192.168.122.0/24 --enable_dhcp=False --allocation-pool start=192.168.122.10,end=192.168.122.200 --gateway-ip 192.168.122.1
	Created a new subnet:
	+------------------+-------------------------------------------------------+
	| Field            | Value                                                 |
	+------------------+-------------------------------------------------------+
	| allocation_pools | {"start": "192.168.122.10", "end": "192.168.122.99"} |
	| cidr             | 192.168.122.0/24                                      |
	| dns_nameservers  |                                                       |
	| enable_dhcp      | False                                                 |
	| gateway_ip       | 192.168.122.1                                         |
	| host_routes      |                                                       |
	| id               | 0b1ce2ce-2908-45db-8b9b-d7cbdefcfc5c                  |
	| ip_version       | 4                                                     |
	| name             |                                                       |
	| network_id       | 7382ead9-faba-405a-a78f-404c236c9334                  |
	| tenant_id        | aec5e4f4e53144fb828c22e77b1e620a                      |
	+------------------+-------------------------------------------------------+
	
The allocation pool above is what we will eventually use as both our router range *AND* our floating-ip range (for external access), hence why I advise you start it at 10 and end at 99 so you're not over-riding IP's already in use.

Networks can be verified like so:

	# quantum net-list
	+--------------------------------------+------+-------------------------------------------------------+
	| id                                   | name | subnets                                               |
	+--------------------------------------+------+-------------------------------------------------------+
	| 7382ead9-faba-405a-a78f-404c236c9334 | ext  | 89ee4bc1-073e-4ccd-a108-6c839dad011d 192.168.122.0/24 |
	+--------------------------------------+------+-------------------------------------------------------+
	
	# quantum subnet-list
	+--------------------------------------+------+------------------+-------------------------------------------------------+
	| id                                   | name | cidr             | allocation_pools                                      |
	+--------------------------------------+------+------------------+-------------------------------------------------------+
	| 89ee4bc1-073e-4ccd-a108-6c839dad011d |      | 192.168.122.0/24 | {"start": "192.168.122.10", "end": "192.168.122.99"}  |
	+--------------------------------------+------+------------------+-------------------------------------------------------+
	
#**Lab 8: Installation and configuration of Horizon (Frontend)**

**Prerequisites:**
* All of the previous labs completed, i.e. Keystone, Cinder, Nova and Glance installed

##**Introduction**

Horizon is OpenStack's official implementation of a dashboard, a web-based front-end for the OpenStack services such as Nova, Cinder, Keystone etc. It provides an extensible framework for implementing features for new technologies as they emerge, e.g. billing and metering. The dashboard offers two main views, one for the administrators and a more limited 'self-service' style portal on offer to the end-users. The dashboard can be customised or "branded" so that logos for varios distributions or service-providers can be inserted. Of course, Horizon directly interfaces with the API's that OpenStack opens up and therefore OpenStack can fully function *without* Horizon but it's a nice addition to have.

This lab will install Horizon on-top of your existing infrastructure and we'll use it to deploy our first instances in the next lab.

Estimated completion time: 20 minutes.

##**Installing Horizon**

As with all OpenStack components, their location within the cloud is largely irrelevant. However, for convenience we'll install Horizon on our cloud controller node. Note that Horizon is known as 'openstack-dashboard':

	# ssh root@openstack-controller
	# source keystonerc_admin

	# yum install openstack-dashboard -y

By default, SELinux will be enabled, we need to make sure that httpd can connect out to Keystone:

	# setsebool -P httpd_can_network_connect on

We can then start the service (the dashboard exists as a configuration plugin to Apache):

	# service httpd start
	# chkconfig httpd on

You can then navigate to http://192.168.122.101/dashboard (or http://openstack-controller/dashboard if you have updated your hosts file)- you can use your user account to login as well as the admin one to see the differences. Don't expect everything to work as expected (yet), we've not finished the installation!

Note: We've not explicity set-up SSL yet, this guide avoids the use of SSL, although in future production deployments it would be prudent to use SSL for communications and configure the systems accordingly. 

#**Lab 9: Deployment of Instances**

**Prerequisites:**
* All of the previous labs completed, i.e. Keystone, Cinder, Nova, Quantum and Glance installed

##**Background Information**

We're going to be starting our first instances in this lab. There are a few key concepts that we must understand in order to fully appreciate what this lab is trying to achieve. Firstly, networking; this is a fundamental concept within OpenStack and is quite difficult to understand when first starting off. OpenStack networking provides two methods of getting network access to instances, 1) nova-network and 2) Quantum, what we've configured so far is Quantum as it's replacing nova-network as of Grizzly, although it's still possible to use it. 

For an instance to start, it must be assigned a network to attach to. These are typically private networks, i.e. have no public connectivity and is primarily used for virtual machine interconnects and private networking. Within OpenStack we bridge the private network out to the real world via a public (or 'external') network, it is simply the network interface in which public traffic will connect into, and is typically where you'd assign "floating IP's", i.e. IP addresses that are dynamically assigned to instances so that external traffic can be routed through correctly. Instances don't actually have direct access to the public network interface, they only see the private network and the administrator is responsible for optionally connecting a virtual router to interlink the two networks for both external access and inbound access from outside the private network.

We've already created our external network and ensured that Open vSwitch knows which interface to bridge external traffic to, it can be confirmed by using:

	# ssh root@openstack-controller
	# source keystonerc_admin

	# quantum net-show ext
	+---------------------------+--------------------------------------+
	| Field                     | Value                                |
	+---------------------------+--------------------------------------+
	| admin_state_up            | True                                 |
	| id                        | 7382ead9-faba-405a-a78f-404c236c9334 |
	| name                      | ext                                  |
	| provider:network_type     | vlan                                 |
	| provider:physical_network | physnet1                             |
	| provider:segmentation_id  | 1000                                 |
	| router:external           | True                                 |
	| shared                    | False                                |
	| status                    | ACTIVE                               |
	| subnets                   | 89ee4bc1-073e-4ccd-a108-6c839dad011d |
	| tenant_id                 | aec5e4f4e53144fb828c22e77b1e620a     |
	+---------------------------+--------------------------------------+
	
The key parameter above is that 'router:external=True'.

This is great, but instances won't have direct access to this network, we need to create private networks for our tenants. This is the responsibility of a user within a tenant, the external network is just exposed to all of the tenants that are created; whilst they cannot modify it, they can attach a virtual router to it for connectivity.

The next step is for us to create a tenant network, whilst we can create them within the 'admin' tenant, let's use our 'demo' tenant previously created-

	# source keystonerc_user
	# quantum net-create int
	Created a new network:
	+-----------------+--------------------------------------+
	| Field           | Value                                |
	+-----------------+--------------------------------------+
	| admin_state_up  | True                                 |
	| id              | 0191c293-365d-4798-aa2d-f5afe47100c2 |
	| name            | int                                  |
	| router:external | False                                |
	| shared          | False                                |
	| status          | ACTIVE                               |
	| subnets         |                                      |
	| tenant_id       | 97b43bd18e7c4f7ebc45b39b090e9265     |
	+-----------------+--------------------------------------+
	
	# quantum subnet-create int 30.0.0.0/24 --dns_nameservers list=true 192.168.122.1
	Created a new subnet:
	+------------------+--------------------------------------------+
	| Field            | Value                                      |
	+------------------+--------------------------------------------+
	| allocation_pools | {"start": "30.0.0.2", "end": "30.0.0.254"} |
	| cidr             | 30.0.0.0/24                                |
	| dns_nameservers  | 192.168.122.1                              |
	| enable_dhcp      | True                                       |
	| gateway_ip       | 30.0.0.1                                   |
	| host_routes      |                                            |
	| id               | df839eb2-8efc-413d-a19a-3e008da4858f       |
	| ip_version       | 4                                          |
	| name             |                                            |
	| network_id       | 0191c293-365d-4798-aa2d-f5afe47100c2       |
	| tenant_id        | 97b43bd18e7c4f7ebc45b39b090e9265           |
	+------------------+--------------------------------------------+
	
Note that we've forwarded our network to push DNS requests out to our underlying hypervisor, although we don't YET have connectivity to this network as there's no virtual router linking the two together, let's change that...

	# quantum router-create router1
	Created a new router:
	+-----------------------+--------------------------------------+
	| Field                 | Value                                |
	+-----------------------+--------------------------------------+
	| admin_state_up        | True                                 |
	| external_gateway_info |                                      |
	| id                    | 992bfd5f-25ab-474b-b959-be2610333a4e |
	| name                  | router1                              |
	| status                | ACTIVE                               |
	| tenant_id             | 97b43bd18e7c4f7ebc45b39b090e9265     |
	+-----------------------+--------------------------------------+
	
Now let's connect the two networks together, firstly we need to set the gateway, i.e. the external network and then add an interface which is the subnet we're linking to (our internal network 30.0.0.0/24).

	# quantum router-gateway-set router1 ext
	Set gateway for router router1
	
	# quantum router-interface-add router1 0191c293-365d-4798-aa2d-f5afe47100c2
	Added interface to router router1

Every instance that starts will need to be assigned a private network to attach to, in our example it will be on 30.0.0.0/24, the network address is assigned via DHCP by dnsmasq (via quantum-dhcp-agent) running on our cloud controller. Note that all of the above is simplified by the OpenStack dashboard, which you'll see shortly.

The second element to be aware of is images; Glance provides the repository of disk images, when the Nova scheduler instructs a compute-node to start an instance it retrieves the required disk image and stores it locally on the hypervisor, it then uses this image as a backing store for any number of instances' disk images; i.e. for each instance started, a delta/qcow2 is instantiated which only tracks the differences, the underlying disk image is untouched.

Finally, instances come in all different shapes and sizes, known as flavors in OpenStack. This mimics what many public cloud providers offer. Out of the box, OpenStack ships with five different offerings, each with varying numbers of virtual CPUs, memory, disk space etc. When starting an instance, this is one of the choices that will be offered to you. 

This lab will go through the following:

* Creation of instances via the console and dashboard
* Configuring a VNC proxy to view the console output

##**Starting instances via the console**

Let's launch our first instance in OpenStack using the command line. Firstly we need to find out a few things, the flavor size and the image we want to start, plus we have to give it a name:

	# ssh root@openstack-controller
	# source keystonerc_user

	# nova flavor-list
	+----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
	| ID | Name      | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public | extra_specs |
	+----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
	| 1  | m1.tiny   | 512       | 0    | 0         |      | 1     | 1.0         | True      | {}          |
	| 2  | m1.small  | 2048      | 20   | 0         |      | 1     | 1.0         | True      | {}          |
	| 3  | m1.medium | 4096      | 40   | 0         |      | 2     | 1.0         | True      | {}          |
	| 4  | m1.large  | 8192      | 80   | 0         |      | 4     | 1.0         | True      | {}          |
	| 5  | m1.xlarge | 16384     | 160  | 0         |      | 8     | 1.0         | True      | {}          |
	+----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+

	# nova image-list
	+--------------------------------------+------------------------------+--------+--------+
	| ID                                   | Name                         | Status | Server |
	+--------------------------------------+------------------------------+--------+--------+
	| 3dd6cab6-e0da-4cce-887e-520ddd879e07 | Red Hat Enterprise Linux 6.4 | ACTIVE |        |
	+--------------------------------------+------------------------------+--------+--------+

	# nova boot --flavor 1 --image 3dd6cab6-e0da-4cce-887e-520ddd879e07 rhel-test
	+-----------------------------+--------------------------------------+
	| Property                    | Value                                |
	+-----------------------------+--------------------------------------+
	| status                      | BUILD                                |
	| updated                     | 2013-06-17T20:18:58Z                 |
	| OS-EXT-STS:task_state       | scheduling                           |
	| key_name                    | None                                 |
	| image                       | Red Hat Enterprise Linux 6.4         |
	| hostId                      |                                      |
	| OS-EXT-STS:vm_state         | building                             |
	| flavor                      | m1.tiny                              |
	| id                          | 76209a2f-a9df-4100-9cd8-4b7f875d1c3a |
	| security_groups             | [{u'name': u'default'}]              |
	| user_id                     | 246b8c2a23604442a10b5ca77b3b10d2     |
	| name                        | rhel-test                            |
	| adminPass                   | NDWo8F3bsn96                         |
	| tenant_id                   | 97b43bd18e7c4f7ebc45b39b090e9265     |
	| created                     | 2013-06-17T20:18:58Z                 |
	| OS-DCF:diskConfig           | MANUAL                               |
	| metadata                    | {}                                   |
	| accessIPv4                  |                                      |
	| accessIPv6                  |                                      |
	| progress                    | 0                                    |
	| OS-EXT-STS:power_state      | 0                                    |
	| OS-EXT-AZ:availability_zone | nova                                 |
	| config_drive                |                                      |
	+-----------------------------+--------------------------------------+

Note that because we only have one private network, it assumes we want to join this one. Otherwise we would have had to specify a network to use.

	# nova list
	+--------------------------------------+-----------+--------+------------------+
	| ID                                   | Name      | Status | Networks         |
	+--------------------------------------+-----------+--------+------------------+
	| 76209a2f-a9df-4100-9cd8-4b7f875d1c3a | rhel-test | ACTIVE | private=30.0.0.4 |
	+--------------------------------------+-----------+--------+------------------+

As you can see, our machine has been given a network address of 30.0.0.4 and has been started. Finally, lets remove this instance and repeat the process via the dashboard:

	# nova delete rhel-test

##**Starting instances via the Dashboard**

1. Login to the dashboard (with your user account, not admin) at http://192.168.122.101/dashboard
2. Select 'Instances' on the left-hand side
3. Select 'Launch Instance' in the top-right
4. Choose 'Red Hat Enterprise Linux 6.4' from the Image drop-down box
5. Give the instance a name
6. Ensure that 'm1.tiny' is selected in the Flavour drop-down box
7. Select the 'Networking' tab at the top and drag the private network from the 'available networks' area
8. Select 'Launch' in the bottom right-hand corner of the pop-up window

You'll notice that the instance will begin building and will provide you with an updated overview of the instance. Let's remove this VM before continuing with the lab...

1. For the instance in question, in the final column 'Actions' click the drop-down arrow
2. Select 'Terminate Instance'
3. Confirm termination

##**Viewing Console Output (VNC)**

Via the OpenStack Dashboard (Horizon) as well as via the command-line tools we can access both the console log and the VNC console, we need to configure VNC first though. OpenStack provides a component called novncproxy, this proxies connections from clients to the compute nodes running the instances themselves. 

Connections come into the novncproxy service only, it then creates a tunnel through to the VNC server, meaning VNC servers need not be open to everyone, purely the proxy service. Whilst it can be installed anywhere, we should install the proxy service on our cloud controller node:

	# ssh root@openstack-controller
	# source keystonerc_admin

	# yum install openstack-nova-novncproxy -y

Then, set the configuration for novncproxy up; on the cloud controller (openstack-controller):

	# openstack-config --set /etc/nova/nova.conf DEFAULT \
		novncproxy_base_url http://192.168.122.101:6080/vnc_auto.html

	# openstack-config --set /etc/nova/nova.conf DEFAULT \
		vnc_enabled true

On the compute node:

	# openstack-config --set /etc/nova/nova.conf DEFAULT \
		novncproxy_base_url http://192.168.122.101:6080/vnc_auto.html

	# openstack-config --set /etc/nova/nova.conf DEFAULT \
		vncproxy_url http://192.168.122.101:6080

	# openstack-config --set /etc/nova/nova.conf DEFAULT \
		vnc_enabled true
	
	# openstack-config --set /etc/nova/nova.conf DEFAULT \
		vncserver_listen 192.168.122.102
	
	# openstack-config --set /etc/nova/nova.conf DEFAULT \
		vncserver_proxyclient_address 192.168.122.102

Finally, changes to the iptables rules on our compute node need to be made for incoming VNC server connections. The default firewall rules that ship out of the box with RHEL only typically allow ssh access. We need to make a modification to the base iptables rules to allow access from VNC clients, namely the VNC service.

	# lokkit -p 5900-5999:tcp

On the cloud controller we need to start and enable two services for VNC to work properly, the first is the novncproxy service itself and the second is the console service which is responsible for token-based authentication:

	# service openstack-nova-novncproxy start
	# service openstack-nova-consoleauth start

	# chkconfig openstack-nova-novncproxy on
	# chkconfig openstack-nova-consoleauth on

Finally, restart the compute services on the the compute-node:

	# ssh root@openstack-compute1 service openstack-nova-compute restart

VNC consoles are only available to instances created when 'vnc_enabled = True' is configured in /etc/nova/nova.conf, therefore we have to create a new instance to verify it's working correctly:

	# ssh root@openstack-controller
	# source keystonerc_user

	# nova image-list
	+--------------------------------------+------------------------------+--------+--------+
	| ID                                   | Name                         | Status | Server |
	+--------------------------------------+------------------------------+--------+--------+
	| af094839-814e-4b76-99c4-9470a8b91903 | Red Hat Enterprise Linux 6.4 | ACTIVE |        |
	+--------------------------------------+------------------------------+--------+--------+

	# nova boot --flavor 1 --image af094839-814e-4b76-99c4-9470a8b91903 rhel
	+-----------------------------+--------------------------------------+
	| Property                    | Value                                |
	+-----------------------------+--------------------------------------+
	| status                      | BUILD                                |
	| updated                     | 2013-06-17T20:18:58Z                 |
	| OS-EXT-STS:task_state       | scheduling                           |
	| key_name                    | None                                 |
	| image                       | Red Hat Enterprise Linux 6.4         |
	| hostId                      |                                      |
	| OS-EXT-STS:vm_state         | building                             |
	| flavor                      | m1.tiny                              |
	| id                          | c38fb239-370a-4d6f-87e2-5adf34aaa936 |
	| security_groups             | [{u'name': u'default'}]              |
	| user_id                     | 246b8c2a23604442a10b5ca77b3b10d2     |
	| name                        | rhel                                 |
	| adminPass                   | NDWo8F3bsn96                         |
	| tenant_id                   | 97b43bd18e7c4f7ebc45b39b090e9265     |
	| created                     | 2013-06-17T20:18:58Z                 |
	| OS-DCF:diskConfig           | MANUAL                               |
	| metadata                    | {}                                   |
	| accessIPv4                  |                                      |
	| accessIPv6                  |                                      |
	| progress                    | 0                                    |
	| OS-EXT-STS:power_state      | 0                                    |
	| OS-EXT-AZ:availability_zone | nova                                 |
	| config_drive                |                                      |
	+-----------------------------+--------------------------------------+

There's two ways of accessing the VNC console using novncproxy; either via the dashboard, simply select the instance and select the 'VNC' tab, or use the command-line utility and navigate to the URL specified:

	# nova list
	+--------------------------------------+------+--------+------------------+
	| ID                                   | Name | Status | Networks         |
	+--------------------------------------+------+--------+------------------+
	| c38fb239-370a-4d6f-87e2-5adf34aaa936 | rhel | BUILD  | private=30.0.0.4 |
	+--------------------------------------+------+--------+------------------+

	# nova get-vnc-console rhel novnc
	+-------+--------------------------------------------------------------------------------------+
	| Type  | Url                                                                                  |
	+-------+--------------------------------------------------------------------------------------+
	| novnc | http://192.168.122.101:6080/vnc_auto.html?token=164d6792-53b8-40d4-a2ba-6fee409bd514 |
	+-------+--------------------------------------------------------------------------------------+

#**Lab 10: Attaching Floating IP's to Instances**

##**Introduction**

So far we've started instances, these instances have received private internal IP addresses (not typically routable outside of the OpenStack environment) and we can view the console via a VNC proxy in a web-browser. The next step is to configure access to these instances from outside of the private network.

As a recap, the cloud controller acts as a networking node in this configuration, via the L3-agent it provides the instances with both inbound and outbound networking using one or more physical interfaces (configured as 'br-int' and 'br-ex'). In a production environment a separate management network would be used for communication between the OpenStack components and an additional dedicated public network interface, completely isolated from the management and inter-instance networks.

OpenStack allows us to assign 'floating IPs' to instances to allow network traffic from any external interface to be routed to a specific instance. The IP's assigned come directly from one or more external networks, thankfully we've already created one. Behind the scenes the node running the L3-agent listens on an additional IP address and uses NAT to tunnel the traffic to the correct instance on the private network. Quantum allows us to define these floating IP's and it can be configured to automatically assign them on boot (in addition to the private network, of course) or you can choose to assign them dynamically via the command line tools. 

##**Creating Floating Addresses**

For this task you'll need an instance running first, if you don't have one running revisit the previous lab and start an instance. We'll request floating IP's from a pool that we've already assigned, this is known as the allocation pool on the external network.

	# ssh root@openstack-controller
	# source keystonerc_user

OpenStack makes you 'claim' an IP from the available list of IP addresses for the tenant (project) you're currently running in before you can assign it to an instance, we specify the 'ext' network to claim from:

	# quantum floatingip-create ext
	Created a new floatingip:
	+---------------------+--------------------------------------+
	| Field               | Value                                |
	+---------------------+--------------------------------------+
	| fixed_ip_address    |                                      |
	| floating_ip_address | 192.168.122.11                       |
	| floating_network_id | 7382ead9-faba-405a-a78f-404c236c9334 |
	| id                  | 2f8a9079-55fa-44ab-b2c9-99685d7f3664 |
	| port_id             |                                      |
	| router_id           |                                      |
	| tenant_id           | 97b43bd18e7c4f7ebc45b39b090e9265     |
	+---------------------+--------------------------------------+

You can see that it's attached to our tenant, i.e. 'demo'.

##**Assigning an address**

Next, we can assign our claimed IP address to an instance. Unfortunately the command-line tools could do with a bit of work to make them a lot easier to do this. To associate an IP address we need the floating-ip id and the Quantum port-id of our instances virtual NIC.

The first thing to do is check the IP address of our started instance:

	# nova list
	+--------------------------------------+------+--------+------------------+
	| ID                                   | Name | Status | Networks         |
	+--------------------------------------+------+--------+------------------+
	| 843441f6-b8ab-4ed9-9231-3326ee19e6ec | test | ACTIVE | private=30.0.0.2 |
	+--------------------------------------+------+--------+------------------+
	
Next, take the floating-IP id:

	# quantum floatingip-list
	+--------------------------------------+------------------+---------------------+---------+
	| id                                   | fixed_ip_address | floating_ip_address | port_id |
	+--------------------------------------+------------------+---------------------+---------+
	| 2f8a9079-55fa-44ab-b2c9-99685d7f3664 |                  | 192.168.122.11      |         |
	+--------------------------------------+------------------+---------------------+---------+
	
Then, check the port-id for this assigned IP address:

	# quantum port-list | grep 30.0.0.2 | awk '{print $2;}'
	d8233763-a214-47db-80bb-76885a06205b
	
Finally, associate them:

	# quantum floatingip-associate 2f8a9079-55fa-44ab-b2c9-99685d7f3664 d8233763-a214-47db-80bb-76885a06205b
	Associated floatingip 2f8a9079-55fa-44ab-b2c9-99685d7f3664
	
Verify using:

	# quantum floatingip-list
	+--------------------------------------+------------------+---------------------+--------------------------------------+
	| id                                   | fixed_ip_address | floating_ip_address | port_id                              |
	+--------------------------------------+------------------+---------------------+--------------------------------------+
	| 2f8a9079-55fa-44ab-b2c9-99685d7f3664 | 30.0.0.2         | 192.168.122.11      | d8233763-a214-47db-80bb-76885a06205b |
	+--------------------------------------+------------------+---------------------+--------------------------------------+
	
	# nova list
	+--------------------------------------+------+--------+----------------------------------+
	| ID                                   | Name | Status | Networks                         |
	+--------------------------------------+------+--------+----------------------------------+
	| 843441f6-b8ab-4ed9-9231-3326ee19e6ec | test | ACTIVE | private=30.0.0.2, 192.168.122.11 |
	+--------------------------------------+------+--------+----------------------------------+

If you want to go a bit further to check the router is actually listening on the new floating IP address we can dive into the network namespaces:

	# ip netns list
	qrouter-6bea3ee4-47d6-4a3e-a9da-c82fed18baa0
	qdhcp-7bdfd266-65da-4552-af23-40769791808a
	
	# ip netns exec qrouter-6bea3ee4-47d6-4a3e-a9da-c82fed18baa0 ip a
	14: lo: <LOOPBACK,UP,LOWER_UP> mtu 16436 qdisc noqueue state UNKNOWN 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
	19: qr-4c2be66e-1e: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether fa:16:3e:2e:ee:fc brd ff:ff:ff:ff:ff:ff
    inet 30.0.0.1/24 brd 30.0.0.255 scope global qr-4c2be66e-1e
    inet6 fe80::f816:3eff:fe2e:eefc/64 scope link 
       valid_lft forever preferred_lft forever
	21: qg-11f2d170-ba: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether fa:16:3e:cd:2b:20 brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.10/24 brd 192.168.122.255 scope global qg-11f2d170-ba
    inet 192.168.122.11/32 brd 192.168.122.11 scope global qg-11f2d170-ba
    inet6 fe80::f816:3eff:fecd:2b20/64 scope link 
       valid_lft forever preferred_lft forever
       
Above you can see that this router is listening on a number of interfaces. First is 30.0.0.1 which represents our gateway for our internal network. It's also listening on 192.168.122.10, the Open vSwitch gateway to the external network as well as our floating IP, 192.168.122.11.

Note: Trying to ping your floating IP will currently fail, see the next section for details...

##**OpenStack Security Groups**

By default, OpenStack Security Groups prevent any access to instances via the public network, including ICMP/ping! Therefore, we have to manually edit the security policy to ensure that the firewall is opened up for us. Let's add two rules, firstly for all instances to have ICMP and SSH access. By default, Quantum ships with a 'default' security group, it's possible to create new groups and assign custom rules to these groups and then assign these groups to individual servers. For this lab, we'll just configure the default group.

First, enable ICMP for *every* node:

	# quantum security-group-rule-create --protocol icmp --remote-ip-prefix 0.0.0.0/0 default
	Created a new security_group_rule:
	+-------------------+--------------------------------------+
	| Field             | Value                                |
	+-------------------+--------------------------------------+
	| direction         | ingress                              |
	| ethertype         | IPv4                                 |
	| id                | dba33ff9-c616-4d8c-90ee-40512de5313d |
	| port_range_max    |                                      |
	| port_range_min    |                                      |
	| protocol          | icmp                                 |
	| remote_group_id   |                                      |
	| remote_ip_prefix  | 0.0.0.0/0                            |
	| security_group_id | b4f0829a-b4b6-45ed-972b-bc5d0e55bd58 |
	| tenant_id         | 97b43bd18e7c4f7ebc45b39b090e9265     |
	+-------------------+--------------------------------------+

Within a few seconds (for the Quantum L3-agent on the controller node to pick the changes up) you should be able to ping your floating IP:

	# ping -c4 192.168.122.11
	PING 192.168.122.11 (192.168.122.11) 56(84) bytes of data.
	64 bytes from 192.168.122.11: icmp_seq=1 ttl=63 time=2.32 ms
	64 bytes from 192.168.122.11: icmp_seq=2 ttl=63 time=0.965 ms
	...

We can ping, but we can't SSH yet, as that's still not allowed:

	# ssh -v root@192.168.122.11
	OpenSSH_5.3p1, OpenSSL 1.0.0-fips 29 Mar 2010
	debug1: Reading configuration data /etc/ssh/ssh_config
	debug1: Applying options for *
	debug1: Connecting to 192.168.122.11 [192.168.122.11] port 22.
	debug1: connect to address 192.168.122.11 port 22: Connection timed out
	ssh: connect to host 192.168.122.11 port 22: Connection timed out

Next, let's try adding another rule, to allow SSH access for all instances in the group:

	# quantum security-group-rule-create --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 default
	Created a new security_group_rule:
	+-------------------+--------------------------------------+
	| Field             | Value                                |
	+-------------------+--------------------------------------+
	| direction         | ingress                              |
	| ethertype         | IPv4                                 |
	| id                | b8ed2037-be88-4f26-bd4d-887558f94288 |
	| port_range_max    | 22                                   |
	| port_range_min    | 22                                   |
	| protocol          | tcp                                  |
	| remote_group_id   |                                      |
	| remote_ip_prefix  | 0.0.0.0/0                            |
	| security_group_id | b4f0829a-b4b6-45ed-972b-bc5d0e55bd58 |
	| tenant_id         | 97b43bd18e7c4f7ebc45b39b090e9265     |
	+-------------------+--------------------------------------+

And, let's retry the SSH connection..

	# ssh root@192.168.122.11
	The authenticity of host '192.168.122.11 (192.168.122.11)' can't be established.
	RSA key fingerprint is 18:71:dd:3d:c5:cf:6b:5a:73:d4:e3:0b:11:af:7a:ec.
	Are you sure you want to continue connecting (yes/no)? yes
	Warning: Permanently added '192.168.122.11' (RSA) to the list of known hosts.
	root@192.168.122.11's password: 
	[root@test ~]#

Let's clean-up this instance before we proceed with the next section:

	# nova list
	+--------------------------------------+------+--------+----------------------------------+
	| ID                                   | Name | Status | Networks                         |
	+--------------------------------------+------+--------+----------------------------------+
	| 843441f6-b8ab-4ed9-9231-3326ee19e6ec | test | ACTIVE | private=30.0.0.2, 192.168.122.11 |
	+--------------------------------------+------+--------+----------------------------------+
	# nova delete test

##**Automating Floating IP Allocation**

For convenience, many people choose to configure OpenStack to automatically claim and assign floating IP addresses. Unfortunately in Grizzly/Quantum, it's not currently supported whereas it was with the previous nova-network implementation. Therefore the old section of this guide has been removed.


#**Lab 11: Configuring the Metadata Service for Customisation**

##**Introduction**

OpenStack provides a metadata service for instances to receive some instance-specific configuration after first-boot and mimics what public cloud offerings such as Amazon AWS/EC2 provide. A prime example of data contained in the metadata service is a public key, one that can be used to connect directly into an instance via ssh. Other examples include executable code ('user-data'), allocating system roles, security configurations etc. In this lab we'll do two things, register and use a public key for authentication and execute a post-boot script on our instances.

OpenStack provides the metadata API via a RESTful interface, the API listens on a designated nide and awaits a connection from a client. Clients that want to access the metadata service *always* use a specific IP address (169.254.169.254), Quantum automatically routes all HTTP connections to this address to the Nova metadata-api via the quantum-metadata-agent service and is therefore aware of which instance made the connection; again, this is done via NAT.

The data contained by the service is created by the users upon creation of an instance, OpenStack provides multiple ways of including this data, dependent on the type of information being included. It's down to the creators of the VM image to configure the boot-up process so that it automatically connects into the metadata service and retrieves (and processes) the data. There are two primary ways of doing this, the first option is to handcrank a first-boot script that sifts through the metadata and applies any changes manually, the second is to use 'cloud-init', a package that understands the metadata service and knows how to make the required changes over a wide variety of Linux-based operating systems. For example, if a public key has been assigned to an instance, it will automatically download it and install it into the correct location.

##**Enabling the Metadata API**

The metadata API service sits on a designated node, in this lab we'll enable it on the cloud controller (openstack-controller). We need to change a few configuration options as well as start some services:

	# ssh root@openstack-controller
	
First, configure Nova so that it knows what to do when we start the metadata-api service:
	
	# openstack-config --set /etc/nova/nova.conf DEFAULT metadata_host 192.168.122.101
	# openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen 0.0.0.0
	# openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen_port 8775
	# openstack-config --set /etc/nova/nova.conf DEFAULT service_quantum_metadata_proxy True
	# openstack-config --set /etc/nova/nova.conf DEFAULT quantum_metadata_proxy_shared_secret metasecret123

Now configure the Quantum metadata agent, it needs to know how to communicate with Keystone:

	# openstack-config --set /etc/quantum/metadata_agent.ini DEFAULT auth_url http://192.168.122.101:35357/v2.0/
	# openstack-config --set /etc/quantum/metadata_agent.ini DEFAULT auth_region regionOne
	# openstack-config --set /etc/quantum/metadata_agent.ini DEFAULT admin_tenant_name services
	# openstack-config --set /etc/quantum/metadata_agent.ini DEFAULT admin_user quantum
	# openstack-config --set /etc/quantum/metadata_agent.ini DEFAULT admin_password quantumpasswd

And it then needs to know how to connect out to Nova as this service is merely a Proxy:

	# openstack-config --set /etc/quantum/metadata_agent.ini DEFAULT nova_metadata_ip 192.168.122.101
	# openstack-config --set /etc/quantum/metadata_agent.ini DEFAULT nova_metadata_port 8700
	# openstack-config --set /etc/quantum/metadata_agent.ini DEFAULT metadata_proxy_shared_secret metasecret123
	
The L3-agent sets up the routing for us, therefore we should specify how it should route the requests to the metadata-api;

	#  openstack-config --set /etc/quantum/l3_agent.ini DEFAULT metadata_ip 192.168.122.101
	#  openstack-config --set /etc/quantum/l3_agent.ini DEFAULT metadata_port 8700
	
Next, update the Nova configuration file on the controller to ensure it listens on this port for metadata:

	# openstack-config --set /etc/nova/nova.conf DEFAULT metadata_host 192.168.122.101
	# openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen 0.0.0.0
	# openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen_port 8700
	# openstack-config --set /etc/nova/nova.conf DEFAULT service_quantum_metadata_proxy True
	# openstack-config --set /etc/nova/nova.conf DEFAULT quantum_metadata_proxy_shared_secret metasecret123

Enable the TCP port through the firewall:

	# lokkit -p 8700:tcp
	
Start and enable the services:

	# chkconfig quantum-metadata-agent on
	# service quantum-metadata-agent start
	# service openstack-nova-api restart
	# service quantum-l3-agent restart
	
You can check the routing quite easily on the cloud controller, it shows that port 80 for 169.254.169.254 routes to the host at port 8700, just remember to check it on the correct namespace:

	# ip netns list
	qrouter-6bea3ee4-47d6-4a3e-a9da-c82fed18baa0
	qdhcp-7bdfd266-65da-4552-af23-40769791808a
	
	# ip netns exec qrouter-6bea3ee4-47d6-4a3e-a9da-c82fed18baa0 iptables -L -t nat | grep 169
	REDIRECT   tcp  --  anywhere             169.254.169.254     tcp dpt:http redir ports 8700 


##**Uploading public keys**

Public keys are used in OpenStack (and other cloud platforms) to uniquely identify a user, avoiding any password requirements. It's also useful when you have passwords installed by users in their VM images but they aren't shared; with a key a user can log-in and change the password to something they're happy with. When an instance is created, one of the options is to select a public key to assign or to upload one into the OpenStack database.

If you're familiar with SSH keys, it's likely that you already have a public key that's ready to be uploaded into Nova, however if not, you can follow these instructions:

	# ssh-keygen
	Generating public/private rsa key pair.
	Enter file in which to save the key (/home/user/.ssh/id_rsa):
	Created directory '/home/user/.ssh'.
	Enter passphrase (empty for no passphrase):
	Enter same passphrase again:
	Your identification has been saved in /home/user/.ssh/id_rsa.
	Your public key has been saved in /home/user/.ssh/id_rsa.pub.
	The key fingerprint is:
	f7:29:b0:5e:aa:1a:73:a0:73:f8:54:c3:c6:12:8b:73 user@usersys
	The key's randomart image is:
	+--[ RSA 2048]----+
	|                 |
	|                 |
	|    .            |
	|   . =           |
	|  o E * S .      |
	|   = = . + . .   |
	|  + = . . o o    |
	|   = + . o .     |
	|    o...o        |
	+-----------------+

Either way, upload your key either via the dashboard (Project --> Access & Security --> Import Keypair --> Copy/paste code from your id_rsa.pub) or from the command-line:

	# source keystonerc_user
	# nova keypair-add --pub-key /home/user/.ssh/id_rsa.pub mypublickey

Based on your tenant, it will add that public key to be made available to all running instances. If cloud-init is installed on your instances, you'll be able to login to the instance using your key rather than password authentication. 

Note: cloud-init sometimes disables the root user logging in and enabled a 'cloud-user' account instead; please check your VM image when you create it (/etc/cloud/cloud.cfg).

Next, launch an instance and check that you can connect in over SSH *without* it asking you for a password, if the metadata server worked correctly you should be able to. If not, connect in via the console and check for errors by running a 'wget http://169.254.169.254/latest/meta-data/instance-id' and tailing '/var/log/quantum/quantum-ns*'. All of this can be carried out either via the nova CLI commands, or via the dashboard.

##**Executing boot-time scripts**

In the OpenStack dashboard, we can insert script-code that will get executed at boot-time via cloud-init (or similar, depending on distribution), this can be carried out via the CLI also but using the Dashboard makes things easier:

1. Login to the dashboard at 'http://192.168.122.101/dashboard' (or via the hostname if configured in hosts/DNS).
2. Select 'Instances' on the left hand-side
3. Select 'Launch Instance' at the top right
4. Choose your image type and network as normal
5. Select the final tab at the top named 'Post-Creation'
6. Paste in the following:
	#!/bin/bash
	uname -a > /tmp/uname
	date > /tmp/date
7. Select 'Launch' at the bottom of the pop-up window
8. When the machine starts to spawn, associate a floating-ip by choosing 'More' --> 'Associate Floating IP'
9. Refresh the page to display the floating IP that has been assigned

Now, try and connect out to the instance, noting that it may still be booting so be patient! 

	# source keystonerc_user
	# nova list
	+--------------------------------------+--------+--------+----------------------------------+
	| ID                                   | Name   | Status | Networks                         |
	+--------------------------------------+--------+--------+----------------------------------+
	| c025278e-7067-42c0-977c-d428605daafc |  rhel  | ACTIVE | private=30.0.0.2, 192.168.122.11 |
	+--------------------------------------+--------+--------+----------------------------------+
	
	# ssh root@192.168.122.11 cat /tmp/uname
	Linux rhel 2.6.32-358.el6.x86_64 #1 SMP Wed May 29 19:20:22 EDT 2013 x86_64 x86_64 x86_64 GNU/Linux
	
	# ssh root@192.168.122.11 cat /tmp/date
	Tue Jun 11 11:57:55 BST 2013


#**Lab 12: Using Cinder to provide persistent data storage**

##**Introduction**
	
#**Lab 13: Installation and Configuration of OpenStack Heat (Orchestration)**

##**Introduction**

#**Lab 14: Installation and Configuration of OpenStack Ceilometer (Metering)**

##**Introduction**