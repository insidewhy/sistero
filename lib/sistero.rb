require "xdg"

require "sistero/version"
require "yaml"
require "droplet_kit"

APP_NAME = "sistero"

module Sistero
  class Config
    DEFAULTS = {
      :access_token => nil,
      :ssh_key => nil,
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

        write_yaml(cfg_file_path, file_opts) if dirty
      end

      file_opts.merge! opts
      file_opts.each { |k, v| send("#{k}=", v) }
    end
  end

  class Instance
    def initialize(opts = {})
      @config = Config.new(opts)
      @client = DropletKit::Client.new(access_token: @config.access_token)
    end

    def find_vm(vm_name: @config.vm_name, create: false)
      vm = @client.droplets.all.find do |vm|
        vm.name == vm_name
      end

      if vm
        puts "found vm: #{vm_name}"
      elsif create
        puts "creating vm: #{vm_name}"
        vm = DropletKit::Droplet.new(
          name: vm_name, region: @config.vm_region, size: "#{@config.vm_size}mb", image: @config.vm_image
        )
        vm = @client.droplets.create(vm)
        puts "created vm: #{vm_name}"
      end
      vm
    end

    def ssh_to_vm(vm_name: @config.vm_name, ssh_options: "")
      vm = find_vm(vm_name: vm_name, create: true)
      public_network = vm.networks.v4.find { |network| network.type == 'public' }
      if not public_network
        puts "no public interfaces"
        return
      end
      ip = public_network.ip_address
      puts "TODO: ssh to #{ip} (options: #{ssh_options})"
    end
  end
end
