require "sistero/version"
require "sistero/config"
require "droplet_kit"

module Sistero
  class Instance
    def initialize(opts = {})
      @config = Config.new(opts)
      @client = DropletKit::Client.new(access_token: @config.defaults.access_token)
    end

    def find_droplet(name)
      @client.droplets.all.find { |droplet| droplet.name == name }
    end

    def list_vms()
      @client.droplets.all.each do |droplet|
        puts "#{droplet.name} - #{get_public_ip droplet}"
      end
    end

    def get_vm name
      vm = @config.vm name
      name = vm.name if name.nil?
      [ vm, name ]
    end

    def create_droplet_from_vm(name)
      vm, name = get_vm name
      puts "creating vm: #{name}"

      droplet = DropletKit::Droplet.new(
        name: name,
        region: vm.region,
        size: vm.size,
        image: vm.image,
        ssh_keys: vm.ssh_keys,
        user_data: vm.user_data,
        private_networking: vm.private_networking
      )
      droplet = @client.droplets.create(droplet)
      puts "created: #{vm.to_s}"
      droplet
    end

    def create_all
      @config.vms.each do |vm|
        create_droplet_from_vm vm.name
      end
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

    def ssh_to_vm(name, ssh_options: nil, run: nil)
      vm, name = get_vm name
      ssh_options ||= vm.ssh_options

      droplet = find_droplet(name) || create_droplet_from_vm(name)
      public_ip = get_public_ip droplet
      wait_for_ssh_port public_ip

      cmd = "ssh -o 'StrictHostKeyChecking no' #{ssh_options} #{vm.ssh_user || 'root'}@#{public_ip}"
      unless run.empty?
        cmd += ' ' + run.join(' ')
      end

      # puts cmd
      exec cmd
    end

    def rsync(name, cmd: nil)
      vm, name = get_vm name
      droplet = find_droplet(name) || create_droplet_from_vm(name)
      public_ip = get_public_ip droplet
      wait_for_ssh_port public_ip

      cmd_str = 'rsync ' + cmd.join(' ').gsub('vm:', "#{vm.ssh_user || 'root'}@#{public_ip}:")
      exec cmd_str
    end

    def destroy_vm(name)
      vm, name = get_vm name

      droplet = find_droplet(name)
      if droplet
        puts "destroying #{droplet.id}"
        @client.droplets.delete(id: droplet.id)
      else
        puts "vm #{name} not found"
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

    def show_images
      @client.images.all().each do |image|
        puts "image #{image.slug}"
        puts "  name          #{image.name}"
        puts "  distribution  #{image.distribution}"
        puts "  public        #{image.public}"
        puts "  type          #{image.type}"
        puts "  regions       #{image.regions.join ', '}"
      end
    end

    private
    def find_public_network droplet
      droplet&.networks&.v4.find { |network| network.type == 'public' }
    end

    private
    def get_public_ip droplet
      public_network = find_public_network droplet
      until public_network
        puts "no public interfaces, trying again in a second"
        sleep 1
        droplet = find_droplet(droplet.name)
        public_network = find_public_network droplet
      end
      public_network.ip_address
    end

    def wait_for_ssh_port public_ip
      unless is_port_open? public_ip, 22
        puts "waiting for ssh port to open"
        sleep 1
        until is_port_open? public_ip, 22 do
          sleep 1
        end
      end
    end
  end
end
