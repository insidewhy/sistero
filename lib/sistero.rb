require "sistero/version"
require "yaml"
require "droplet_kit"

APP_NAME = "sistero"

module Sistero
  class Config
    DEFAULTS = {
      :access_token => nil,
      :ssh_keys => [],
      :ssh_options => '',
      :vm_name => nil,
      :vm_size => 512,
      :vm_region => 'nyc3',
      :vm_image => 'ubuntu-14-04-x64',
    }

    attr_accessor *DEFAULTS.keys

    def write_yaml(path, opts)
      File.open(path, 'w') { |f| f.write opts.to_yaml }
    end

    def initialize(opts = {})
      # read defaults from config file
      cfg_file_path = "#{ENV['HOME']}/.config/#{APP_NAME}"
      file_opts = {}
      file_opts = YAML.load_file cfg_file_path if File.exists? cfg_file_path

      dirty = false
      DEFAULTS.each do |key, default|
        next if file_opts[key]
        dirty = true
        if default
          print "#{key} [#{default}] = "
          val = gets.strip
          val = default if val == ''
        else
          print "#{key} = "
          val = gets.strip
        end
        file_opts[key] = val
      end
      write_yaml(cfg_file_path, file_opts) if dirty

      file_opts.merge! opts
      file_opts.each { |k, v| send("#{k}=", v) }
    end
  end

  class Instance
    def initialize(opts = {})
      @config = Config.new(opts)
      @client = DropletKit::Client.new(access_token: @config.access_token)
    end

    def find_vm(vm_name: @config.vm_name)
      @client.droplets.all.find { |vm| vm.name == vm_name }
    end

    def list_vms()
      @client.droplets.all.each do |vm|
        puts "#{vm.name} - #{vm.networks[0][0].ip_address}"
      end
    end

    def create_vm(vm_name: @config.vm_name)
      puts "creating vm: #{vm_name}"
      vm = DropletKit::Droplet.new(
        name: vm_name, region: @config.vm_region, size: "#{@config.vm_size}mb", image: @config.vm_image, ssh_keys: @config.ssh_keys
      )
      vm = @client.droplets.create(vm)
      puts "created vm: #{vm_name}"
      vm
    end

    def ssh_to_vm(vm_name: @config.vm_name, ssh_options: @config.ssh_options)
      ssh_options = @config.ssh_options if ssh_options == nil
      vm = find_vm(vm_name: vm_name) || create_vm(vm_name: vm_name)
      public_network = vm.networks.v4.find { |network| network.type == 'public' }
      until public_network
        puts "no public interfaces, trying again in a second"
        sleep 1
        vm = find_vm(vm_name: vm_name)
        public_network = vm.networks.v4.find { |network| network.type == 'public' }
      end
      ip = public_network.ip_address

      # TODO: wait for ssh port to be open
      cmd = "ssh #{ssh_options} root@#{ip}"
      puts cmd
      exec cmd
    end

    def destroy_vm(vm_name: @config.vm_name)
      vm = find_vm(vm_name: vm_name)
      if vm
        puts "destroying #{vm.id}"
        @client.droplets.delete(id: vm.id)
      else
        puts "vm not found"
      end
    end
  end
end
