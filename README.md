RosaLab ABF
===================

**Note: This Documentation is in a beta state. Breaking changes may occur.**

## abf-worker

### on Server

You should have access by **ssh** as **root** user for all servers

### on DEV PC

    # Install "ansible", see: http://docs.ansible.com/intro_installation.html
    git clone git@abf.io:abf/abf-ansible.git
    cd abf-ansible
    cp abf-worker.hosts.example abf-worker.hosts
    # Update "abf-worker.hosts" file
    ansible-playbook -i abf-worker.hosts abf-worker.yml


