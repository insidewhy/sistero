require "sistero/version"
require "yaml"
require "droplet_kit"

APP_NAME = "sistero"

module Sistero
  Profile = Struct.new(:access_token, :ssh_keys, :ssh_options, :vm_name, :vm_size, :vm_region, :vm_image)
  # DEFAULTS = {
  #   :access_token => nil,
  #   :ssh_keys => [],
  #   :ssh_options => '',
  #   :vm_name => nil,
  #   :vm_size => 512,
  #   :vm_region => 'nyc3',
  #   :vm_image => 'ubuntu-14-04-x64',
  # }

  class Config
    attr_accessor :defaults

    def profile name
      @profiles[name] || @defaults
    end

    def initialize(opts = {})
      # read defaults from config file
      cfg_file_path = "#{ENV['HOME']}/.config/#{APP_NAME}"
      @defaults = Profile.new
      @profiles = {}

      cfg = YAML.load_file cfg_file_path
      cfg['defaults'].each do |key, value|
        @defaults[key] = value
      end

      cfg.each do |name, profile_cfg|
        next if name == 'defaults'
        profile = @profiles[name] = Profile.new *@defaults
        profile_cfg.each do |key, value|
          profile[key] = value
        end
      end
    end
  end

  class Instance
    def initialize(opts = {})
      @config = Config.new(opts)
      @client = DropletKit::Client.new(access_token: @config.defaults.access_token)
    end

    def find_vm(vm_name:)
      @client.droplets.all.find { |vm| vm.name == vm_name }
    end

    def list_vms()
      @client.droplets.all.each do |vm|
        puts "#{vm.name} - #{vm.networks[0][0].ip_address}"
      end
    end

    def create_vm(profile_name, vm_name: nil)
      profile = @config.profile profile_name
      vm_name ||= profile.vm_name

      puts "creating vm: #{vm_name}"

      vm = DropletKit::Droplet.new(
        name: vm_name,
        region: profile.vm_region,
        size: profile.vm_size,
        image: profile.vm_image,
        ssh_keys: profile.ssh_keys
      )
      vm = @client.droplets.create(vm)
      puts "created vm: #{profile.to_s}"
      vm
    end

    def is_port_open?(ip, port)
      begin
        Timeout::timeout(1) do
          begin
            s = TCPSocket.new(ip, port)
            s.close
            return true
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            return false
          end
        end
      rescue Timeout::Error ; end

      return false
    end

    def ssh_to_vm(profile_name, vm_name: nil, ssh_options: nil)
      profile = @config.profile profile_name
      vm_name ||= profile.vm_name
      ssh_options ||= profile.ssh_options

      vm = find_vm(vm_name: vm_name) || create_vm(profile_name, vm_name: vm_name)
      public_network = vm.networks.v4.find { |network| network.type == 'public' }
      until public_network
        puts "no public interfaces, trying again in a second"
        sleep 1
        vm = find_vm(vm_name: vm_name)
        public_network = vm.networks.v4.find { |network| network.type == 'public' }
      end
      ip = public_network.ip_address

      unless is_port_open? ip, 22
        puts "waiting for ssh port to open"
        sleep 1
        until is_port_open? ip, 22 do
          sleep 1
        end
      end

      cmd = "ssh -o 'StrictHostKeyChecking no' #{ssh_options} root@#{ip}"
      puts cmd
      exec cmd
    end

    def destroy_vm(profile_name, vm_name: nil)
      profile = @config.profile profile_name
      vm_name ||= profile.vm_name

      vm = find_vm(vm_name: vm_name)
      if vm
        puts "destroying #{vm.id}"
        @client.droplets.delete(id: vm.id)
      else
        puts "vm #{vm_name} not found"
      end
    end
  end
end
