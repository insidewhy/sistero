require "yaml"
APP_NAME = "sistero"

module Sistero
  PROFILE_KEYS = [:vm_name, :vm_size, :vm_region, :vm_image, :access_token, :ssh_user,
                  :ssh_keys, :ssh_options, :user_data, :private_networking]

  Profile = Struct.new(*PROFILE_KEYS) do
    def to_s
      "vm #{vm_name}\n" + PROFILE_KEYS.map do |key|
        val = self[key]
        if val and key != :vm_name
          "  #{key} #{val}\n"
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
      @cfg_file_path = opts[:cfg_file_path]
      unless @cfg_file_path
        @cfg_file_path = 'sistero.yaml'
        @cfg_file_path = "#{ENV['HOME']}/.config/#{APP_NAME}" unless File.exists? @cfg_file_path
      end

      @defaults = Profile.new
      @profiles = []

      cfg = YAML.load_file @cfg_file_path
      postprocess_cfg cfg

      cfg['defaults'].each do |key, value|
        @defaults[key] = value
      end

      @profiles = cfg['profiles'].map do |profile_cfg|
        profile = Profile.new *@defaults
        profile_cfg.each do |key, value|
          profile[key] = value
        end
        unless profile.user_data.nil?
          user_data = profile.user_data.dup
          PROFILE_KEYS.each do |key|
            value = profile[key]
            if value.is_a? String
              user_data.gsub! "\#{#{key}}", value
            end
          end
          profile.user_data = user_data
        end
        profile
      end

      @profiles.push(@defaults) if @defaults.vm_name
    end

    def to_s
      @profiles.map(&:to_s).join "\n"
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
