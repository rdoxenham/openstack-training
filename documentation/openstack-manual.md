Title: OpenStack SA Training - Lab Manual<br>
Author: Rhys Oxenham <roxenham@redhat.com><br>
Date: March 2013

#**Lab Contents**#

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

<!--BREAK-->

#**OpenStack Training Overview**

##**Assumptions**

This manual assumes that you're attending instructor-led training classes and that this manual will provide a step-by-step guide on how to complete the labs. Prior knowledge gained from the instructor presentations is expected, however for those wanting to complete this training via their own self-learning, a description is provided.

It is also assumed that a Linux-based hypervisor is being used, ideally KVM/libvirt but it would also be possible to complete this training with alternative platforms, the requirements where necessary are outlined throughout the course. It is highly recommended that the physical machine(s) being used to host the OpenStack environment have plenty of RAM; the course advises that four virtual machines are created, each with their own varying degrees of compute resource requirements. 

By undertaking this course you understand that I take no responsibility for any losses incurred and that you are following the instructions at your own free will. A working knowledge of virtualisation, the Linux command-line, networking, storage and scripting will be highly advantageous for anyone following this guide.

##**What to expect from the course**


