class RMT::CLI::Subcommand < RMT::CLI::Base

  class << self

    def help(shell, subcommand = false)
      meth = normalize_command_name(default_command)
      command = all_commands[meth]

      shell.say 'Usage:'
      shell.say "  #{banner(command)}".sub(/ #{default_command}/, '')
      shell.say
      class_options_help(shell, nil => command.options.values)
      if command.long_description
        shell.say 'Description:'
        shell.print_wrapped(command.long_description, indent: 2)
      else
        shell.say command.description
      end
      shell.say

      list = printable_commands(true, subcommand)
      list.reject! { |l| l[0].split.include?('help') }
      shell.say 'Subcommands:'
      shell.print_table(list, indent: 2, truncate: true)
      shell.say
      class_options_help(shell)

      shell.say "Run '#{basename} #{itself_name} help [SUBCOMMAND]' for more information on a subcommand."
    end

    def default_command_help(shell)
    end

    def itself_name
      itself.to_s.split('::').last.downcase
    end

  end

end
