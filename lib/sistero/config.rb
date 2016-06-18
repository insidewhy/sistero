require "yaml"
APP_NAME = "sistero"

module Sistero
  VM_KEYS = [:name, :size, :region, :image, :access_token, :user_data, :private_networking,
             :ssh_keys, :ssh_options, :ssh_user ]

  VM = Struct.new(*VM_KEYS) do
    def to_s
      "vm #{name}\n" + VM_KEYS.map do |key|
        val = self[key]
        if val and key != :name
          "  #{key} #{val}\n"
        else
          ""
        end
      end.join
    end
  end

  class Config
    attr_accessor :defaults, :vms

    def vm name
      name ||= @defaults['name']
      raise "must set a default name or specify one" unless name
      # TODO: also handle wildcards
      vm = @vms.find do |vm|
        vm.name == name
      end
      raise "could not find vm for #{name}" unless vm
      vm
    end

    def initialize(opts = {})
      # read defaults from config file
      @cfg_file_path = opts[:cfg_file_path]
      unless @cfg_file_path
        @cfg_file_path = 'sistero.yaml'
        @cfg_file_path = "#{ENV['HOME']}/.config/#{APP_NAME}" unless File.exists? @cfg_file_path
      end

      @defaults = VM.new
      @vms = []

      cfg = YAML.load_file @cfg_file_path
      postprocess_cfg cfg

      cfg['defaults'].each do |key, value|
        @defaults[key] = value
      end

      @vms = cfg['vms'].map do |vm_cfg|
        vm = VM.new *@defaults
        vm.name = nil

        vm_cfg.each do |key, value|
          vm[key] = value
        end
        unless vm.user_data.nil?
          user_data = vm.user_data.dup
          VM_KEYS.each do |key|
            value = vm[key]
            if value.is_a? String
              user_data.gsub! "\#{#{key}}", value
            end
          end
          vm.user_data = user_data
        end
        raise "every vm must have a name field" unless vm.name
        vm
      end
    end

    def to_s
      @vms.map(&:to_s).join "\n"
    end

    private
    def postprocess_cfg config
      if config.is_a? Array
        config.map &method(:postprocess_cfg)
      elsif config.is_a? Hash
        if config.length == 1 and config.has_key? 'file'
          File.read(File.join File.dirname(@cfg_file_path), config['file']).strip
        else
          config.update(config) { |key, val| postprocess_cfg val }
        end
      else
        config
      end
    end
  end
end
