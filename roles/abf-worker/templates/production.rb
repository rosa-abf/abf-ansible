set :branch, "{{ branch }}"
# Update 'vm.yml' config file at deploy
set :update_vm_yml, true

set :worker, "localhost"

role :rpm, worker, primary: true
