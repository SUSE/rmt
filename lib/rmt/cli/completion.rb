class RMT::CLI::Completion
  @cli_words = []
  @current_word = ''
  @previous_word = ''

  def initialize
    split_cli_feed
    determine_current_word
    determine_previous_word
  end

  def split_cli_feed
    @cli_words = ENV['COMP_LINE'].split(' ')
    if ENV['COMP_LINE'][-1] == ' '
      @cli_words.append('')
    end
  end

  def correct_capitalization?
    @cli_words.join == @cli_words.join.downcase
  end

  def static_completion_possible?(index: 1, words: @cli_words[0..@cli_words.length - 2])
    if words.length < 3
      return true
    end

    sub_command = words[index]
    super_command = words[index - 1]

    if words.length == index
      return true
    end

    if generate_static_options(command: super_command).include? sub_command
      return static_completion_possible?(index: index + 1, words: words)
    end

    return false
  end

  def determine_current_word
    @current_word = @cli_words.last
  end

  def determine_previous_word
    if @cli_words.length > 1
      @previous_word = @cli_words[@cli_words.length - 2]
    else
      @previous_word = ''
    end
  end

  def generate_static_options(command: @previous_word)
    submodule = command.slice(0, 1).capitalize + command.slice(1, command.length).downcase
    options = []

    # exceptions:
    if command == 'rmt-cli' || command =='help' then submodule = 'Main' end
    if command == 'repo' then submodule = 'Repos' end
    if command == 'product' then submodule = 'Products' end
    if command == 'custom' then submodule = 'ReposCustom' end
    if command == 'rmt-cli' then options.append('help') end

    begin
      options.concat RMT::CLI.module_eval(submodule).commands.keys
    rescue NameError
    end

    return options
  end

  def generate_completions
    completions = []
    static_options = generate_static_options

    static_options.each do |option|
      if option.start_with?(@current_word)
        completions.append(option)
      end
    end

    return completions
  end

  def complete
    completions = generate_completions

    print completions.join("\n")
  end

end
