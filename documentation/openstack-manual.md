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
	# virsh net-create /usr/share/libvirt/networks/default.xml

Finally, ensure that the bridge is setup correctly on the host:

	# brctl show
	...
	virbr0		8000.5254005a0a54	yes		virbr0-nic

	# virsh net-info default
	(See above for correct output)


#**Lab 2: Deploying virtual machine instances as base infrastructure**

**Prerequisites:**
* A physical machine configured with a NAT'd network allocated for hosting virtual machines
* An active subscription to Red Hat's OpenStack Distribution -or- package repositories available locally

**Tools used:**
* SSH
* virt command-line tools (e.g. virsh, virt-install, virt-viewer)

##**Introduction**

OpenStack is made up of a number of distinct components, each having their role in making up a cloud. It's certainly possible to have one single machine (either physical or virtual) providing all of the functions, or a complete OpenStack cloud contained within itself. This, however, doesn't provide any form of high availability/resilience and doesn't make efficient use of resources. Therefore, in a typical deployment, multiple machines will be used, each running a set of components that connect to each other via their open API's. When we look at OpenStack there are two main 'roles' for a machine within the cluster, a 'cloud conductor' and a 'compute node'. A 'cloud conductor' is responsible for orchestration of the cloud, responsibilities include scheduling of instances, running self-service portals, providing rich API's and operating a database store. Whilst a 'compute node' is actually very simple, it's main responsibility is to provide compute resource to the cluster and to accept requests to start instances.

This guide establishes four distinct virtual machines which will make up the core components, their individual purposes will not be explained in this section, the purpose of this lab is to quickly provision these machines as the infrastructure that our OpenStack cluster will be based upon.

Estimated completion time: 30 minutes


##**Preparing the base content**

Assuming that you have a RHEL 6 x86_64 DVD iso available locally, you'll need to provide it for the installation. Alternatively, if you want to install via the network you can do so by using the '--location http://<path to installation tree>' tag within virt-install.

To save time, we'll install a single virtual machine and just clone it afterwards, that way they're all identical.

	# virt-install --name node1 --ram 1000 --file /var/lib/libvirt/images/node1.img \
		--cdrom /path/to/dvd.iso --noautoconsole --vnc --file-size 30 \
		--os-variant rhel6 --network network:default
	# virt-viewer node1

I would advise that you choose a basic or minimal installation option and don't install any window managers, as these are virtual machines we want to keep as much resource as we can available, plus a graphical view is not required. Partition layouts can be set to default at this stage also, just make sure the time-zone is set correctly and that you provide a root password. When asked for a hostname, I suggest you don't use anything unique, just specify "server" or "node" as we will be cloning and want things to be 

After the machine has finished installing it will automatically be shut-down, we have to 'sysprep' it to make sure that it's ready to be cloned, this removes any "hardware"-specific elements so that things like networking come up as if they were created individually-

	# yum install libguestfs-tools -y && virt-sysprep -d node1
	...
	
	# virt-clone -o node1 -n node2 -f /var/lib/libvirt/images/node2.img
	Allocating 'node2.img'

	Clone 'node2' created successfully.
	# virt-clone -o node1 -n node3 -f /var/lib/libvirt/images/node3.img
	Allocating 'node3.img'

	Clone 'node3' created successfully.
	# virt-clone -o node1 -n node4 -f /var/lib/libvirt/images/node4.img
	Allocating 'node4.img'

	Clone 'node4' created successfully.

Finally, as an *optional* step for convenience, we can leave the virtual machines as DHCP and manually configure the 'default' network within libvirt to present static addresses via DHCP. To do this we need to discover the MAC addresses for our recently created guests:

	# virsh domiflist node1 | awk '{print $5}'

	(Repeat this step for all guests, making note of the MAC addresses listed)

Then edit the default network to accomodate for the changes-

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
	      		<host mac='52:54:00:fd:e7:03' name='node1' ip='192.168.122.101' />
      			<host mac='52:54:00:c4:b7:f6' name='node2' ip='192.168.122.102' />
      			<host mac='52:54:00:81:84:d6' name='node3' ip='192.168.122.103' />
      			<host mac='52:54:00:6a:9b:1a' name='node4' ip='192.168.122.104' />
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

Once the above steps have been completed, you'll need to start your machines, login and make some minor adjustments
