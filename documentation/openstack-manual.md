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
* A DVD iso of Red Hat Enterprise Linux 6.4 x86_64
* An active subscription to Red Hat's OpenStack Distribution -or- package repository available locally

**Tools used:**
* SSH
* Virtual Machine Manager (KVM/libvirt)
* yum (for updates) 


##**Introduction**

This first lab will prepare your local environment for deploying virtual machine instances that OpenStack will be installed onto; this is considered an "all-in-one" solution, a single physical system where the virtual machines provide the infrastructure. There are a number of tasks that need to be carried out in order to prepare the environment; the OpenStack nodes will need a network to communicate with each other, it will also be extremely beneficial to provide the nodes with access to package repositories via the Internet or repositories available locally, therefore a NAT based network is a great way of establishing network isolation (your hypervisor just becomes the gateway for your OpenStack nodes). The instructions configure a RHEL/Fedora based environment to provide this network configuration and make sure we have persistent addresses.

Estimated completion time: 10 minutes


##**Preparing the environment**


