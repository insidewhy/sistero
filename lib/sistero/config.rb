require "yaml"
APP_NAME = "sistero"

module Sistero
  PROFILE_KEYS = [:vm_name, :vm_size, :vm_region, :vm_image, :access_token, :ssh_keys, :ssh_options]

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
end
