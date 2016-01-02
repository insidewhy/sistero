require "sistero/version"
require "sistero/config"
require "droplet_kit"

module Sistero
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
      puts "created: #{profile.to_s}"
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

    def show_ssh_keys
      @client.ssh_keys.all().each do |key|
        puts "#{key.name}: #{key.id}"
      end
    end

    def show_sizes
      @client.sizes.all().each do |size|
        puts "size #{size.slug}"
        puts "  regions    #{size.regions.join ', '}"
        puts "  available  #{size.available}"
      end
    end

    def show_regions
      @client.regions.all().each do |region|
        puts "region #{region.slug}" + (region.available ? '' : ' (unavailable)')
        puts "  name       #{region.name}"
        if region.available
          puts "  sizes      #{region.sizes.join ', '}"
          puts "  features   #{region.features.join ', '}"
        end
      end
    end
  end
end
