class OptionParserExtra < OptionParser
  def initialize(config = {})
    @config = config
    super
  end

  # like OptionParser#on but if a block is not supplied the last argument (which
  # should be a string) is used as a hash key to store that value within @config.
  def on *opts, &block
    if block
      super *opts, &block
    else
      key = opts.pop
      super *opts do |val|
        @config[key] = val
      end
    end
  end
end

class SubcommandOptionParser < OptionParserExtra
  def initialize
    # options applicable to all subcommands
    @for_all = []
    @subcommands = {}
    super
  end

  def subcommand name, banner, &block
    @subcommands[name] = { name: name, banner: banner, parse_cmdline: block }
  end

  # add a block to configure every subcommand
  def for_all &block
    @for_all.push block
  end

  def to_s
    ret = super
    max_len = @subcommands.values.map { |subcmd| subcmd[:name].length }.max
    ret += "\ncommands:\n"
    @subcommands.values.each do |subcmd|
      prefix = subcmd[:name]
      prefix += ' ' * (max_len - prefix.length + 2)
      ret += "    #{prefix}  #{subcmd[:banner]}\n"
    end
    ret
  end

  def parse!(args = ARGV)
    apply_for_all self
    order! args
    raise "must supply subcommand" if args.empty?

    cmd = args.first
    subcmd_meta = @subcommands[cmd]
    raise "invalid subcommand: #{cmd}" unless @subcommands.has_key? cmd
    args.shift

    positionals = OptionParserExtra.new(@config) do |subop|
      apply_for_all subop
      subop.banner = subcmd_meta[:banner]
      parse_cmdline = subcmd_meta[:parse_cmdline]
      parse_cmdline.call(subop) if parse_cmdline
    end.order! args

    { cmd: cmd, args: positionals, config: @config }
  end

  def parse(args = ARGV)
    parse! args.clone
  end

 private
  def apply_for_all op
    @for_all.each { |block| block.call op } unless @for_all.empty?
  end
end
