# frozen_string_literal: true

require 'optparse'

module SubmodulerParent
  class StatusCommand
    def initialize(args)
      @args = args
      parse_options
    end

    def execute
      puts "Checking parent repository status..."
      puts ""
      
      check_parent_status
      check_children_status
      
      0
    rescue StandardError => e
      puts "Error: #{e.message}"
      1
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: bin/submoduler_parent.rb status [options]"
        
        opts.on('-h', '--help', 'Display this help') do
          puts opts
          exit 0
        end
      end.parse!(@args)
    end

    def check_parent_status
      puts "Parent Repository:"
      
      status_output = `git status --short 2>&1`
      
      if $?.success?
        if status_output.strip.empty?
          puts "  ✓ Working tree is clean"
        else
          puts "  ✗ Working tree has changes:"
          status_output.each_line do |line|
            puts "    #{line.strip}"
          end
        end
      else
        puts "  ✗ Error checking git status"
      end
      
      puts ""
    end

    def check_children_status
      return unless File.exist?('.gitmodules')
      
      puts "Child Submodules:"
      
      submodules = parse_gitmodules
      
      if submodules.empty?
        puts "  ℹ No child submodules found"
        return
      end
      
      submodules.each do |submodule|
        check_submodule_status(submodule)
      end
    end

    def parse_gitmodules
      submodules = []
      current_submodule = nil
      
      File.readlines('.gitmodules').each do |line|
        if line =~ /\[submodule "(.+)"\]/
          current_submodule = { name: $1 }
          submodules << current_submodule
        elsif line =~ /path = (.+)/ && current_submodule
          current_submodule[:path] = $1.strip
        end
      end
      
      submodules
    rescue
      []
    end

    def check_submodule_status(submodule)
      path = submodule[:path]
      name = submodule[:name]
      
      puts "  #{name}:"
      
      unless Dir.exist?(path)
        puts "    ✗ Directory does not exist: #{path}"
        return
      end
      
      Dir.chdir(path) do
        status_output = `git status --short 2>&1`
        
        if $?.success?
          if status_output.strip.empty?
            puts "    ✓ Working tree is clean"
          else
            puts "    ✗ Working tree has changes:"
            status_output.each_line do |line|
              puts "      #{line.strip}"
            end
          end
        else
          puts "    ✗ Error checking git status"
        end
      end
    end
  end
end
