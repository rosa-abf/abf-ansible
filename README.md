RosaLab ABF
===================

**Note: This Documentation is in a beta state. Breaking changes may occur.**

## Prepare environment

You should have access by **ssh** as **root** user for all servers.
All command should be called from local PC

    # Install "ansible", see: http://docs.ansible.com/intro_installation.html
    git clone git@abf.io:abf/abf-ansible.git
    cd abf-ansible

## rosa-build

    cp rosa-build.hosts.example rosa-build.hosts
    # Update "rosa-build.hosts" and "rosa-build.yml" files
    ansible-playbook -i rosa-build.hosts rosa-build.yml

## abf-downloads

    cp abf-downloads.hosts.example abf-downloads.hosts
    # Update "abf-worker.hosts" file
    ansible-playbook -i abf-downloads.hosts abf-downloads.yml

## abf-worker

    cp abf-worker.hosts.example abf-worker.hosts
    # Update "abf-worker.hosts" file

    # NOTE: for MDV distros you should run this command more 2 times as minimum
    ansible-playbook -i abf-worker.hosts abf-worker.yml


## File-Store

    cp file-store.hosts.example file-store.hosts
    # Update "file-store.hosts" file
    ansible-playbook -i file-store.hosts file-store.yml


