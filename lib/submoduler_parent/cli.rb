# frozen_string_literal: true

require 'optparse'

module SubmodulerParent
  class CLI
    COMMANDS = {
      'status' => 'Display status of parent and all child submodules',
      'test' => 'Run tests across parent and all child submodules',
      'push' => 'Push changes to parent and all child submodules',
      'report' => 'Generate configuration and status reports',
      'release' => 'Manage release workflow for parent and children',
      'symlink_build' => 'Build symlinks from vendor gems to parent .kiro/steering'
    }.freeze

    def self.run(args)
      new(args).run
    end

    def initialize(args)
      @args = args
      @command = nil
      @options = {}
    end

    def run
      verify_parent_context

      if @args.empty?
        display_help
        return 1
      end

      @command = @args.shift

      unless COMMANDS.key?(@command)
        puts "Error: Unknown command '#{@command}'"
        display_help
        return 1
      end

      execute_command
    rescue StandardError => e
      puts "Error: #{e.message}"
      1
    end

    private

    def verify_parent_context
      config_file = '.submoduler.ini'
      
      unless File.exist?(config_file)
        raise "Not in a Submoduler directory. Missing #{config_file}"
      end

      content = File.read(config_file)
      
      unless content.match?(/master\s*=/)
        raise "Invalid .submoduler.ini: missing 'master' configuration"
      end
    end

    def execute_command
      case @command
      when 'status'
        StatusCommand.new(@args).execute
      when 'test'
        TestCommand.new(@args).execute
      when 'symlink_build'
        SymlinkBuildCommand.run
        0
      when 'push'
        PushCommand.new(@args).execute
      when 'report'
        puts "Report command not yet implemented"
        0
      when 'release'
        puts "Release command not yet implemented"
        0
      else
        puts "Error: Command '#{@command}' not implemented"
        1
      end
    end

    def display_help
      puts "Submoduler Parent - Manage parent repository operations"
      puts ""
      puts "Usage: bin/submoduler_parent.rb <command> [options]"
      puts ""
      puts "Available commands:"
      COMMANDS.each do |cmd, desc|
        puts "  #{cmd.ljust(12)} #{desc}"
      end
      puts ""
      puts "Run 'bin/submoduler_parent.rb <command> --help' for command-specific options"
    end
  end
end
