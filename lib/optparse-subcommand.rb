class SubcommandOptionParser < OptionParser
  def initialize
    @subcommands = {}
    super
  end

  def subcommand name, banner, &block
    @subcommands[name] = { name: name, banner: banner, parse_cmdline: block }
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
    order! args
    raise "must supply subcommand" if args.empty?

    cmd = args.first
    subcmd_meta = @subcommands[cmd]
    raise "invalid subcommand: #{cmd}" unless @subcommands.has_key? cmd
    args.shift

    positionals = OptionParser.new do |subop|
      subop.banner = subcmd_meta[:banner]
      parse_cmdline = subcmd_meta[:parse_cmdline]
      parse_cmdline.call(subop) if parse_cmdline
    end.order! args

    [cmd, positionals]
  end

  def parse(args = ARGV)
    parse! args.clone
  end
end
