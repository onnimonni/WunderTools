require 'yaml'

# local variables
settings = YAML.load_file 'conf/vagrant_local.yml'

INSTANCE_NAME     = settings['name']
INSTANCE_HOSTNAME = settings['hostname']
INSTANCE_MEM      = settings['mem']
INSTANCE_CPUS     = settings['cpus']
INSTANCE_IP       = settings['ip']
INSTANCE_BOX      = settings['box']
ANSIBLE_INVENTORY = "ansible/inventory"

dir = File.dirname(__FILE__) + '/../'

system(dir + "/build.sh")
# Write the inventory file for ansible
FileUtils.mkdir_p dir + ANSIBLE_INVENTORY
File.open(dir + ANSIBLE_INVENTORY + "/hosts", 'w') { |file| file.write("[vagrant]\n" + INSTANCE_IP) }
# Link the ansible playbook
unless File.exist?(dir + "ansible/playbook/vagrant.yml")
	FileUtils.ln_s "../../conf/vagrant.yml", dir + "ansible/playbook/vagrant.yml"
end

# And never anything below this line
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

	########################################
	# Default configuration
	########################################

	config.vm.hostname = INSTANCE_HOSTNAME
	config.vm.box      = "centos-6.6-x86_64-v0"

	config.vm.network :private_network, ip: INSTANCE_IP

	# Sync folders
	config.vm.synced_folder ".", "/vagrant", type: :nfs

	# Vagrant cachier
	if Vagrant.has_plugin?("vagrant-cachier")
		config.cache.scope = :box
		config.cache.enable :yum
		config.cache.synced_folder_opts = {
			type: :nfs,
			mount_options: ['rw', 'vers=3', 'tcp', 'nolock']
		}
	end

	########################################
	# Configuration for virtualbox
	########################################

	config.vm.provider "virtualbox" do |v, override|
		override.vm.box_url = "https://www.dropbox.com/s/mo7tjw15z5ep6p6/vb-centos-6.6-x86_64-v0.box?dl=1"
	end

	config.vm.provider :virtualbox do |vb|
		vb.name = INSTANCE_NAME
		vb.customize ["modifyvm", :id, "--memory", INSTANCE_MEM, "--cpus", INSTANCE_CPUS, "--ioapic", "on", "--rtcuseutc", "on", "--natdnshostresolver1", "on"]
	end

	########################################
	# Configuration for vmware_fusion
	########################################

	config.vm.provider "vmware_fusion" do |v, override|
		override.vm.box_url = "https://www.dropbox.com/s/tcp23ka9hlhhsel/vm-centos-6.6-x86_64-v0.box?dl=1"
	end

	config.vm.provider "vmware_fusion" do |vb|
		vb.name = INSTANCE_NAME
		vb.vmx["memsize"]  = INSTANCE_MEM
		vb.vmx["numvcpus"] = INSTANCE_CPUS
	end

	########################################
	# Provisioning
	########################################

	config.vm.provision "ansible" do |ansible|
		#ansible.verbose        = "v"
		ansible.inventory_path = ANSIBLE_INVENTORY
		ansible.extra_vars     = "conf/variables.yml"
		ansible.playbook       = "ansible/playbook/vagrant.yml"
		ansible.limit          = "all"
	end

	config.vm.provision :shell, :path => "ansible/shell/provision.sh"
	
end
