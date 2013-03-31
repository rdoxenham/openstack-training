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

OpenStack is made up of a number of distinct components, each having their role in making up a cloud. It's certainly possible to have one single machine (either physical or virtual) providing all of the functions, or a complete OpenStack cloud contained within itself. This, however, doesn't provide any form of high availability/resilience and doesn't make efficient use of resources. Therefore, in a typical deployment, multiple machines will be used, each running a set of components that connect to each other via their open API's. When we look at OpenStack there are two main 'roles' for a machine within the cluster, a 'cloud controller' and a 'compute node'. A 'cloud controller' is responsible for orchestration of the cloud, responsibilities include scheduling of instances, running self-service portals, providing rich API's and operating a database store. Whilst a 'compute node' is actually very simple, it's main responsibility is to provide compute resource to the cluster and to accept requests to start instances.

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

Finally, start your first virtual machine that'll be used in the next lab:

	# virsh start node1

#**Lab 3: Installation and configuration of Keystone (Identity Service)**

**Prerequisites:**
* One of the four virtual machines created in the previous lab
* An active subscription to Red Hat's OpenStack Distribution -or- package repositories available locally

**Tools used:**
* SSH
* subscription-manager
* yum
* OpenStack Keystone

##**Introduction**

Keystone is the identity management component of OpenStack; it supports token-based, username/password and AWS-style logins and is responsible for providing a centralised directory of users mapped to the services they are granted to use. It acts as the common authentication system across the whole of the OpenStack environment and integrates well with existing backend directory services such as LDAP. In addition to providing a centralised repository of users, Keystone provides a catalogue of services deployed in the environment, allowing service discovery with their endpoints (or API entry-points) for access. Keystone is responsible for governance in an OpenStack cloud, it provides a policy framework for allowing fine grained access control over various components and responsibilities in the cloud environment.

As keystone provides the foundation for everything that OpenStack uses this will be the first thing that is installed. For this, we'll take the first node (node1) and turn this into a 'cloud controller' in which, Keystone will be a crucial part of that infrastructure.

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

##**Creating a Keystone Service**

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


##**Creating Users**

From Folsom onwards, all OpenStack services utilise Keystone for authentication. As previously mentioned, Keystone uses tokens that are generated via user authentication, e.g. via a username/password combination. The next few steps create a user account, a 'tenant' (a group of users, or a project) and a 'role' which is used to determine permissions cross the stack. You can choose your own password here, just remember what it is as we'll use it later:

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

To accomodate massive scalability, OpenStack was built using AMQP-based messaging for communication. We're going to install qpidd on our 'cloud condutor' node but we'll disable authentication just for convenience. In a production environment authentication would certainly be enabled and configured properly. We need to install this now as later on in the guide we'll rely on this message bus being available.

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

	# ssh root@node1

Then install the required components:

	# yum install openstack-glance -y

Glance makes use of MySQL to store the glance-registry data, i.e. all of the image metadata. Therefore we need to create the initial database:

	# openstack-db --init --service glance

##**Integrating Glance with Keystone**

Before we start the Glance service, we need to configure it to speak to Keystone to manage authentication. We make heavy use of the openstack-config tool here for convenience although manually modifying the configuration files is also possible. We provide Glance with the required username and password for authenticating as the 'admin' user; which is required to do background user-token checks.

	# openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
	# openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name admin
	# openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_user admin
	# openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_password <admin password>

	# openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
	# openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name admin
	# openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_user admin
	# openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password <admin password>

Note: One additional configuration option change that would usually need to be made is the 'auth_host' option in both /etc/glance/glance-api.conf and /etc/glance/glance-registry.conf, but as we're using Keystone on the *same* server as Glance we can ignore this option as the default behavior is to look at localhost.

We can now start and enable these services upon boot:

	# service openstack-glance-registry start && chkconfig openstack-glance-registry on
	# service openstack-glance-api start && chkconfig openstack-glance-api on

To complete the integration, a service an an associated end-point need to be created in Keystone:

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

Firstly, we need to get access to an image, if you're following this guide from Lab 1 you'll realise that we built a number of virtual machines to run our OpenStack virtual machines themselves, their own disk images can be copied for this purpose, and we've already used 'virt-sysprep' to remove any system-specific configuration. Let's take one of those virtual machine images and copy it to our node running Glance. First we have to create a new disk image from our 'node4' machine by converting the old disk image type to a 'qcow2' format. The reason why we convert it is so that we don't copy the full 30GB disk size, we only copy the 'used' data; if it's in the 'raw' format, the filesystem thinks the entire 30GB is to be copied.

	(First, open up a *new* terminal on your physical host machine, Note: NOT nodeX)

	# qemu-img convert -O qcow2 /var/lib/libvirt/images/node4.img /tmp/rhel64.qcow2
	# scp /tmp/rhel64.qcow2 root@node1:/tmp/rhel64.img
	# rm /tmp/rhel64.qcow2

Return back to your node1 machine where you have your ssh session running. Let's verify that the disk image was copied across successfully and has the correct properties:

	# yum install qemu-img -y

	# qemu-img info /tmp/rhel64.qcow2
	image: /tmp/rhel64.qcow2
	file format: qcow2
	virtual size: 30G (32212254720 bytes)
	disk size: 2.6G
	cluster_size: 65536

Note: If you've opted to use a disk-image you've already created outside of these labs, I strongly advise that you use 'virt-sysprep' to prepare the machine before importing.

Next we can create a new image within Glance and import its contents, it may take a few minutes to copy the data. The 'user' account should be used to upload the image rather than the administrator:

	# source ~/keystonerc_user

	# glance image-create --name "Red Hat Enterprise Linux 6.4" --is-public true \
		--disk-format qcow2 --container-format bare \
		--file /tmp/rhel64.qcow2
	+------------------+--------------------------------------+
	| Property         | Value                                |
	+------------------+--------------------------------------+
	| checksum         | 8935cd7b7e5008edc7806f446828fa8d     |
	| container_format | bare                                 |
	| created_at       | 2013-03-28T00:48:15                  |
	| deleted          | False                                |
	| deleted_at       | None                                 |
	| disk_format      | qcow2                                |
	| id               | af094839-814e-4b76-99c4-9470a8b91903 |
	| is_public        | True                                 |
	| min_disk         | 0                                    |
	| min_ram          | 0                                    |
	| name             | Red Hat Enterprise Linux 6.4         |
	| owner            | 58a576bfd7b34df1afb372c1c905798e     |
	| protected        | False                                |
	| size             | 2805858304                           |
	| status           | active                               |
	| updated_at       | 2013-03-28T00:49:07                  |
	+------------------+--------------------------------------+


The container format is 'bare' because it doesn't require any additional images such as a kernel or initrd, it's completely self-contained. The 'is-public' option allows any user within the tenant (project) to use the image rather than locking it down for the specific user uploading the image.

We'll use this image for deploying instances on OpenStack in the next few labs.


#**Lab 5: Installation and configuration of Cinder (Volume Service)**

**Prerequisites:**
* Keystone installed and configured as per Lab 3

##**Introduction**

Cinder is OpenStack's volume service, it's responsible for managing persistent block storage, i.e. the creation of a block device, it's lifecycle, connections to instances and it's eventual deletion. Block storage is a requirement in OpenStack for many reasons, firstly persistence but also for performance scenarios, e.g. access to data backed by tiered storage. Cinder supports many different back-ends in which it can connect to and manage storage for OpenStack, including HP's LeftHand, EMC, IBM, Ceph and NetApp, although it does support a basic Linux storage model, based on iSCSI. Cinder was once part of Nova (the OpenStack Compute service, which we'll come onto later on in this guide) and was known as nova-volume; it's since been divorced from Nova in order to allow each distinct component to evolve independently. 

##**Installing Cinder**

For the installation of Cinder, we'll use our second virtual machine that we created, it will provide one of the core services in the OpenStack environment and doesn't provide compute resource to the cluster. As per the previous setup, we need to quickly register this machine with the Red Hat Network and make sure it has access to the required components. Brief instructions are provided below, further details can be found in Lab 3:

	# virsh start node2
	# ssh root@node2

	(On node2)
	# subscription-manager register
	# subscription-manager list --available
	# subscription-manager subscribe --pool <RHEL Pool> --pool <OpenStack Pool>
	
	# yum install yum-utils -y
	# yum-config-manager --enable rhel-server-ost-6-folsom-rpms --setopt="rhel-server-ost-6-folsom-rpms.priority=1"
	# yum update -y && reboot

Once the machine is fully up to date and has been rebooted, we can begin the installation of Cinder:

	# ssh root@node2
	# yum install openstack-cinder -y

##**Configuring Cinder**

Cinder uses a MySQL database to hold information about the volumes that it's managing; it's possible to have this data sitting in the same database as the other services we've created, e.g. Keystone and Glance on 'node1' however for simplicity, we'll configure an additional database on 'node2' using openstack-db:

	# yum install openstack-utils -y
	# openstack-db --init --service cinder --password <password>

As with all other OpenStack services, Cinder uses Keystone for authentication, we'll need to configure this to communicate with Keystone running on node1. We can use the handy 'openstack-config' tool to make these changes for us:

	# openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
	# openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name admin
	# openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_user admin
	# openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_password <Keystone admin password>

Additionally, let's update Cinder so it knows which host our Keystone server runs on, note that if you're not using the IP addresses created in Lab 2, your network configuration may be different to the example below:

	# openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_host 192.168.122.101

At the start of this guide we created an AMQP/qpid server for component communication, Cinder is one of those components that makes use of this message queue. We will need to modify our Cinder configuration to point to the server running on node1:

	# openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_hostname 192.168.122.101
	# openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_port 5672

##**Preparing storage for Cinder**

The easiest way to get started with Cinder volumes is to just use it's basic in-built (iSCSI-based) volume service; in production you'd likely connect out to an external SAN however this guide will explain how to configure the basic service. For this you need to create a standard LVM volume group named 'cinder-volumes', which Cinder will carve up into individual logical volumes to present as block devices to the compute instances. The initial virtual machines were created with 30GB storage, so we've got enough to create a local VG.

Warning: The instructions below are not recommended for any form of production environment, they provide a mechanism of creating the required volume group but should not be relied on. An additional disk of partition should be used instead...

	# truncate --size 20G /cinder-volumes
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
	VG Size               20.00 GiB
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

Finally, endpoints for the Cinder service need to be added to Keystone. We will need to connect back into our machine hosting Keystone, node1. I'd advise an additional terminal be opened up for this so we can keep our connection open to node2.

	# ssh root@node1
	# source keystonerc_admin

	# keystone service-create --name cinder --type volume --description "Cinder Volume Service"
	+-------------+----------------------------------+
	|   Property  |              Value               |
	+-------------+----------------------------------+
	| description |      Cinder Volume Service       |
	|      id     | 94ed0a651b4342e2a2c25c00c2b271d8 |
	|     name    |              cinder              |
	|     type    |              volume              |
	+-------------+----------------------------------+

And then the endpoint, not forgetting to use the id from the previous command, *NOT* the one you see above in this guide. Also note that we're setting the endpoint to be sitting at node2 and not node1, hence the 192.168.122.102 usage:

	# keystone endpoint-create --service_id 94ed0a651b4342e2a2c25c00c2b271d8 \
		--publicurl "http://192.168.122.102:8776/v1/\$(tenant_id)s" \
		--adminurl "http://192.168.122.102:8776/v1/\$(tenant_id)s" \
		--internalurl "http://192.168.122.102:8776/v1/\$(tenant_id)s"
	+-------------+----------------------------------------------+
	|   Property  |                    Value                     |
	+-------------+----------------------------------------------+
	|   adminurl  | http://192.168.122.102:8776/v1/$(tenant_id)s |
	|      id     |       002bdb25d74f45fe9a202f0fbbb3c97e       |
	| internalurl | http://192.168.122.102:8776/v1/$(tenant_id)s |
	|  publicurl  | http://192.168.122.102:8776/v1/$(tenant_id)s |
	|    region   |                  regionOne                   |
	|  service_id |       94ed0a651b4342e2a2c25c00c2b271d8       |
	+-------------+----------------------------------------------+

Note: We were required to enter 'tenant_id' in the URL string as this gets automatically substituted by the client that's interacting with the API, that way we're only able to see/configure the volumes within that users tenant/project.

##**Testing Cinder**

Finally, return back to your session on node2 (where Cinder is running) and ensure that you can create a volume. Note that you'll require authentication with Keystone, so the easiest thing to do is copy the 'user' rc file from your node1 machine:

	node2 # scp root@node1:/root/keystonerc_user ~/
	
	# source keystonerc_user
	# keystone token-get
	+-----------+----------------------------------+
	|  Property |              Value               |
	+-----------+----------------------------------+
	|  expires  |       2013-03-31T18:33:16Z       |
	|     id    | d1a21139f5ce45d394ceaa8a1dde59f1 |
	| tenant_id | 58a576bfd7b34df1afb372c1c905798e |
	|  user_id  | 3b0682e2872849d780ecde00b8d20e4e |
	+-----------+----------------------------------+

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


#**Lab 6: Installation and configuration of Nova (Compute Service)**

**Prerequisites:**
* Keystone installed and configured as per Lab 3

##**Introduction**

Nova is OpenStack's compute service, it's responsible for providing and scheduling compute resource for OpenStack instances. It's undoubtably the most important part of the OpenStack project. It was designed to massively scale horizontally to cater for the largest clouds. Nova supports a wide variety of hardware and software platforms, including the most popular hypervisors such as KVM, Xen, Hyper-V and VMware ESX, turning traditional virtualisation environments into cloud resource pools. Nova has many different individual components, each of which are responsible for a specific task, examples include a compute driver which is responsible for providing resource to the cloud, a scheduler to respond to and allocate requests from cloud consumers and a network layer which provides inward and outward network traffic to compute instances.

Nova is quite fragmented in its architecture, the scheduler as an example typically sits on a separate machine to the compute nodes, where only the compute and network components exist. As with other components, a message bus exists between all the components allowing the distribution to be completely open and as a result can drastically scale. 

The lab will walk you through deploying Nova across the cluster, utilising our 'cloud controller' (node1) to provide the API and scheduler services and the remaining two virtual machines to provide compute resource (with associated network component). It will also show you how to manage the individual Nova services and integrate with the rest of the stack.

Estimated completion time: 1 hour

##**Preparing the Cloud Controller**

We need to deploy the Nova components on our first node that will provide the API and the scheduler services and will be the endpoint for Nova in our environment. It's important to note that typically the Nova configuration between cloud controller nodes and compute nodes is actually almost identical, it's the Nova services that are started on a particular node that define its responsibilities. Therefore it may seem strange why we're configuring Nova 

	# ssh root@node1
	# source keystonerc_admin

	# openstack-db --init --service nova --password <password>

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
	iscsi_helper = tgtadm
	sql_connection = mysql://nova:<password>@192.168.122.101/nova
	compute_driver = libvirt.LibvirtDriver
	libvirt_type=qemu
	firewall_driver = nova.virt.libvirt.firewall.IptablesFirewallDriver
	rpc_backend = nova.openstack.common.rpc.impl_qpid
	rootwrap_config = /etc/nova/rootwrap.conf
	auth_strategy = keystone
	
	volume_api_class = nova.volume.cinder.API
	enabled_apis = ec2,osapi_compute,metadata
	my_ip=192.168.122.101
	qpid_hostname=192.168.122.101
	qpid_port=5672

	glance_host 192.168.122.101
	
	network_manager=nova.network.manager.FlatDHCPManager
	public_interface=eth0
	flat_network_bridge=br100
	flat_interface=eth0
	
	[keystone_authtoken]
	admin_tenant_name = admin
	admin_user = admin
	admin_password = <password>
	auth_host = 192.168.122.101
	auth_port = 35357
	auth_protocol = http
	signing_dirname = /tmp/keystone-signing-nova

What this configuration is describing is as follows-

* The MySQL database (which holds the instance data) is located on node1
* We want to use Libvirt for the Compute, but qemu based emulation
* We are using iptables to provide the firewall (and routing for networking)
* We are using qpid as the backend messaging broker (and it sits on node1)
* Cinder is the volume manager for providing persistent storage
* Glance is providing the networking and sits on node1
* The machine's IP address is 192.168.122.101 (node1)
* We're using Nova's FlatDHCPManager network config (more to come later)
* And we're using Keystone for authentication.

Note: Remember to change the keystone admin_password entry and the MySQL password to reflect your configuration.	

Just to make sure the file has been created properly:

	# chown root:nova /etc/nova/nova.conf
	# restorecon /etc/nova/nova.conf
	# chmod 640 /etc/nova/nova.conf

That configuration should be enough for the cloud controller machine, we can then start the necessary services on this machine:

	# service openstack-nova-api start
	# service openstack-nova-scheduler start

	# chkconfig openstack-nova-api on
	# chkconfig openstack-nova-scheduler on

##**Preparing the Compute Nodes**

So far we've used two of our four virtual instances, the remaining two will be used as compute nodes which we'll install and configure Nova on. This lab repeats the previous steps of registering and subscribing systems to receive OpenStack channel content:

	# virsh start node3
	# ssh root@node3
	
	# subscription-manager register
	# subscription-manager list --available
	# subscription-manager subscribe --pool <RHEL Pool> --pool <OpenStack Pool>

	# yum install yum-utils -y
	# yum-config-manager --enable rhel-server-ost-6-folsom-rpms --setopt="rhel-server-ost-6-folsom-rpms.priority=1"
	# yum update -y && reboot

Note: I would recommend that you configure one node at a time, so start with node3 and once we have this within the OpenStack environment we can simply copy configuration files over and start the required services.

After the machine has rebooted, connect back in and install the required components:

	# ssh root@node3
	# yum install openstack-nova -y
	# yum install python-cinderclient -y

Also, as this machine will provide resource, we need to ensure that libvirt is installed-

	# yum install libvirt -y
	# chkconfig libvirtd on && service libvirtd start

	# scp root@node1:/etc/nova/nova.conf /etc/nova/nova.conf
	# chown root:nova /etc/nova/nova.conf
	# restorecon /etc/nova/nova.conf
	# chmod 640 /etc/nova/nova.conf

Remember that the nova.conf that was on node1 was slightly configured specifically for node1, we should make a few changes so that it fits with node3's configuration:

	# sed -i 's/my_ip=.*/my_ip=192.168.122.103/g' /etc/nova/nova.conf

Note: If your compute node is not at '192.168.122.103, make the required change in the above sed command, or just manually edit the /etc/nova/nova.conf file.

We can now start the required services on this node, that'll be compute and network:

	# service openstack-nova-compute start
	# service openstack-nova-network start

	# chkconfig openstack-nova-compute on
	# chkconfig openstack-nova-network on

We're now finished with node3 for now, we need to return to our cloud controller (node1) and setup the keystone service and endpoints:

	# ssh root@node1
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

	# nove-manage service list
	Binary           Host         Zone      Status     State   Updated_At
	nova-scheduler   node1        nova      enabled    :-)     2013-03-31 10:47:20
	nova-network     node3        nova      enabled    :-)     2013-03-31 10:47:20
	nova-compute     node3        nova      enabled    :-)     2013-03-31 10:47:21

We can see that nova-scheduler is running on node1 (where nova-api also runs) and nova-network and nova-compute are running on node3. This is all shared via AMQP/qpid. To test integration with Glance, for example:

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

Let's next ensure that the fourth node can join the compute cluster. Repeat the steps undertaken for node3 on node4, when you've copied the Nova configuration file over, make sure you set the IP address accordingly:

	# sed -i 's/my_ip=.*/my_ip=192.168.122.104/g' /etc/nova/nova.conf

You can now start the services on node4:

	# service openstack-nova-compute start
	# service openstack-nova-api start

	# chkconfig openstack-nova-compute on
	# chkconfig openstack-nova-api on

Let's make sure that they've joined the cluster successfully, note you may have to wait 30 seconds for them to appear:

	# nova-manage service list
	Binary           Host    Zone      Status     State   Updated_At
	nova-scheduler   node1   nova      enabled    :-)     2013-03-31 11:26:05
	nova-network     node3   nova      enabled    :-)     2013-03-31 11:26:06
	nova-compute     node3   nova      enabled    :-)     2013-03-31 11:26:06
	nova-compute     node4   nova      enabled    :-)     2013-03-31 11:25:58
	nova-network     node4   nova      enabled    :-)     2013-03-31 11:26:02

Note: One of the most common problems with services being visible but not in a 'happy' state is time inconsistencies. If you're experiencing issues please confirm the date/time first!

If you watch the nova logs on one of the compute nodes, you'll see the nodes checking in and updating their available resource for the scheduler...

	# tail -n5 /var/log/nova/compute.log 
	2013-03-31 13:06:10 1836 AUDIT nova.compute.resource_tracker [-] Free ram (MB): 460
	2013-03-31 13:06:10 1836 AUDIT nova.compute.resource_tracker [-] Free disk (GB): 27
	2013-03-31 13:06:10 1836 AUDIT nova.compute.resource_tracker [-] Free VCPUS: 1
	2013-03-31 13:06:10 1836 INFO nova.compute.resource_tracker [-] Compute_service record updated for node4 
	2013-03-31 13:06:10 1836 INFO nova.compute.manager [-] Updating host status

Finally, we need to create a logical network for our instances. This is a private network that is used for internal communication between instances and their underlying services. Connecting to instances will not be possible from outside of this network at this time, but this is an essential step. The networking provided by iptables will ensure that network traffic connecting in via this private network gets automatically routed to the correct nodes.

	# nova-manage network create private 10.0.0.0/24 1 256 --bridge=br100


#**Lab 7: Installation and configuration of Horizon (Frontend)**

**Prerequisites:**
* All of the previous labs completed, i.e. Keystone, Cinder, Nova and Glance installed

##**Introduction**

Horizon is OpenStack's official implementation of a dashboard, a web-based front-end for the OpenStack services such as Nova, Cinder, Keystone etc. It provides an extensible framework for implementing features for new technologies as they emerge, e.g. billing and metering. The dashboard offers two main views, one for the administrators and a more limited 'self-service' style portal on offer to the end-users. The dashboard can be customised or "branded" so that logos for varios distributions or service-providers can be inserted. Of course, Horizon directly interfaces with the API's that OpenStack opens up and therefore OpenStack can fully function *without* Horizon but it's a nice addition to have.

This lab will install Horizon on-top of your existing infrastructure and we'll use it to deploy our first instances in the next lab.

Estimated completion time: 20 minutes.

##**Installing Horizon**

As with all OpenStack components, their location within the cloud is largely irrelevant. However, for convenience we'll install Horizon on our cloud controller node. Note that Horizon is known as 'openstack-dashboard':

	# ssh root@node1
	# source keystonerc_admin

	# yum install openstack-dashboard -y

By default, SELinux will be enabled, we need to make sure that httpd can connect out to Keystone:

	# setsebool -P httpd_can_network_connect on

In addition, usually Horizon (and Swift, which will be covered later) use a role called "Member", we should create this before we continue:

	# keystone role-create --name Member
	+----------+----------------------------------+
	| Property |              Value               |
	+----------+----------------------------------+
	|    id    | dc414ecbff6e49e79003146a83f092c5 |
	|   name   |              Member              |
	+----------+----------------------------------+

We can then start the service (the dashboard exists as a configuration plugin to Apache):

	# service httpd start
	# chkconfig httpd on

You can then navigate to http://192.168.122.101/dashboard - you can use your user account to login as well as the admin one to see the differences.

Note: We've not explicity set-up SSL yet, this guide avoids the use of SSL, although in future production deployments it would be prudent to use SSL for communications and configure the systems accordingly. 

#**Lab 8: Deployment of first test instances**

**Prerequisites:**
* All of the previous labs completed, i.e. Keystone, Cinder, Nova and Glance installed

We're going to be starting our first instances in this lab. There are a few key concepts that we must understand in order to fully appreciate what this lab is trying to achieve. Firstly, networking; this is a fundamental concept within OpenStack and is quite difficult to understand when first starting off. OpenStack networking provides two methods of getting network access to instances, 1) nova-network and 2) quantum, what we've configured so far is nova-network as it's easy to configure. 

The Nova configuration file specifies multiple interfaces, a "public_interface" and a "flat_interface", the public one is simply the network interface in which public traffic will connect into, and is typically where you'd assign "floating IP's", i.e. IP addresses that are dynamically assigned to instances so that external traffic can be routed through correctly. The flat interface is one in which that is considered private, i.e. has no public connectivity and is primarily used for virtual machine interconnects and private networking. OpenStack relies on a private network for bridging public traffic and routing, therefore it's essential that we configure the private network.

In our test-bed environment, each VM has just a single network interface, therefore both the public and flat networks are provided by the same interface. In addition to these two parameters, we need a bridge interface which links the VM network to the flat interface, in this case we've called it br100 ("flat_network_bridge"). 

A diagram explaining the above can be found [here](http://docs.openstack.org/trunk/openstack-compute/admin/content/figures/7/figures/flatdchp-net.jpg)

We've already created this network in the previous lab and therefore there's nothing more that we need to do. To confirm it's running:

	# ssh root@node1
	# source keystonerc_admin

	# nova-manage network list
	...
