require "sistero/version"
require "yaml"
require "droplet_kit"

APP_NAME = "sistero"

module Sistero
  PROFILE_KEYS = [:vm_name, :vm_size, :vm_region, :vm_image, :access_token, :ssh_keys, :ssh_options]

  Profile = Struct.new(*PROFILE_KEYS) do
    def to_s
      PROFILE_KEYS.map do |key|
        val = self[key]
        if val
          "#{key} #{val}\n"
        else
          ""
        end
      end.join
    end
  end

  class Config
    attr_accessor :defaults, :profiles

    def profile vm_name
      if @defaults['vm_name'] and vm_name.nil?
        profile = @defaults
      else
        # TODO: also handle wildcards
        profile = @profiles.find do |profile|
          profile.vm_name == vm_name
        end
        raise "could not find profile for #{vm_name}" unless profile
      end
      profile
    end

    def initialize(opts = {})
      # read defaults from config file
      cfg_file_path = "#{ENV['HOME']}/.config/#{APP_NAME}"
      @defaults = Profile.new
      @profiles = []

      cfg = YAML.load_file cfg_file_path
      cfg['defaults'].each do |key, value|
        @defaults[key] = value
      end

      @profiles = cfg['profiles'].map do |profile_cfg|
        profile = Profile.new *@defaults
        profile_cfg.each do |key, value|
          profile[key] = value
        end
        profile
      end

      @profiles.push(@defaults) if @defaults['vm_name']
    end

    def to_s
      @profiles.map(&:to_s).join "\n"
    end
  end

  class Instance
    def initialize(opts = {})
      @config = Config.new(opts)
      @client = DropletKit::Client.new(access_token: @config.defaults.access_token)
    end

    def find_vm(vm_name)
      @client.droplets.all.find { |vm| vm.name == vm_name }
    end

    def list_vms()
      @client.droplets.all.each do |vm|
        puts "#{vm.name} - #{vm.networks[0][0].ip_address}"
      end
    end

    def get_profile vm_name
      profile = @config.profile vm_name
      vm_name = profile.vm_name if vm_name.nil?
      [ profile, vm_name ]
    end

    def create_vm(vm_name)
      profile, vm_name = get_profile vm_name
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

    def ssh_to_vm(vm_name, ssh_options: nil)
      profile, vm_name = get_profile vm_name
      ssh_options ||= profile.ssh_options

      vm = find_vm(vm_name) || create_vm(vm_name)
      public_network = vm.networks.v4.find { |network| network.type == 'public' }
      until public_network
        puts "no public interfaces, trying again in a second"
        sleep 1
        vm = find_vm(vm_name)
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

    def destroy_vm(vm_name)
      profile, vm_name = get_profile vm_name

      vm = find_vm(vm_name)
      if vm
        puts "destroying #{vm.id}"
        @client.droplets.delete(id: vm.id)
      else
        puts "vm #{vm_name} not found"
      end
    end

    def show_config
      puts @config.to_s
    end
  end
end
