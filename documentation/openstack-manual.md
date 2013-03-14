Title: OpenStack SA Training - Course Manual<br>
Author: Rhys Oxenham <roxenham@redhat.com><br>
Date: March 2013

#**Course Contents**#

1. **Configuring your host machine for OpenStack**
2. **Deploying RHEL virtual-machine instances**
3. **Installation and configuration of Keystone (Identity Service)**
4. **Installation and configuration of Glance (Image Service)**
5. **Installation and configuration of Cinder (Volume Service)**
6. **Installation and configuration of Nova (Compute Services)**
7. **Installation and configuration of Horizon (OpenStack Frontend)**
8. **Deployment of first test instances**
9. **Configuring Nova to provide metadata service for customisation**
10. **Using Cinder to provide persistent data storage**
11. **Installation and configuration of Quantum (Networking Services)**
12. **Installation and configuration of Swift (Object Storage)**
12. **Deploying and monitoring of instance collections using Heat**
13. **Deploying charge-back and usage monitoring with Celiometer**
14. **Implementing automated deployments with PackStack**

<!--BREAK-->

#**OpenStack Training Overview**

##**Assumptions**

This manual assumes that you're attending instructor-led training classes and that this manual will provide a step-by-step guide on how to complete the labs. Prior knowledge gained from the instructor presentations is expected, however for those wanting to complete this training via their own self-learning, a description is provided.

It is also assumed that a Linux-based hypervisor is being used, ideally KVM/libvirt but it would also be possible to complete this training with alternative platforms, the requirements where necessary are outlined throughout the course. It is highly recommended that the physical machine(s) being used to host the OpenStack environment have plenty of RAM; the course advises that four virtual machines are created, each with their own varying degrees of compute resource requirements. 

By undertaking this course you understand that I take no responsibility for any losses incurred and that you are following the instructions at your own free will. A working knowledge of virtualisation, the Linux command-line, networking, storage and scripting will be highly advantageous for anyone following this guide.

##**What to expect from the course**

Upon completion of the course you should fully understand what OpenStack is designed to do, how the components/building-blocks fit together to provide consumable cloud resources and how to install/configure them. You should feel comfortable designing OpenStack-based architectures and how to position the technology. The course goes into a considerable amount of detail but is far from comprenensive; the target of the course is to provide a solid foundation that can be built upon based on the individuals requirements.

<!--BREAK-->

#**The OpenStack Project**

OpenStack is an open-source Infrastructure-as-a-Service (IaaS) initiative for building and managing large groups of compute instances in an on-demand massively scale-out cloud computing environment. The OpenStack project, led by the OpenStack Foundation has many goals, most importantly is it's initiative to support interoperability between cloud services and to provide all of the building blocks required to establish a cloud that mimics what a public cloud offers you. The difference being, you get the benefits of being able to stand it up behind a corporate firewall.

The OpenStack project has had a significant impact on the IT industry, its adoption has been very wide spread and has become the basis of the cloud offerings from vendors such as HP, IBM and Dell. Other organisations such as Red Hat, Ubuntu and Rackspace are putting together 'distributions' of OpenStack and offering it to their customers as a supported platform for building a cloud; it's truly seen as the "Linux of the Cloud". The project currently has contributions from developers all over the world, vendors are actively developing plugins and contributing code to ensure that OpenStack can exploit the latest features that their software/hardware exposes.

OpenStack is made up of many individual components in a modular architecture that can be put together to create different types of clouds depending on the requirements of the organisation, e.g. pure-compute or cloud storage.

TODO: Finish this ;-)


