# frozen_string_literal: true

require 'optparse'

module SubmodulerParent
  class TestCommand
    def initialize(args)
      @args = args
      @parent_only = false
      @children_only = false
      @specific_submodule = nil
      parse_options
    end

    def execute
      puts "Running tests..."
      puts ""
      
      run_parent_tests unless @children_only
      run_children_tests unless @parent_only
      
      0
    rescue StandardError => e
      puts "Error: #{e.message}"
      1
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: bin/submoduler_parent.rb test [options]"
        
        opts.on('--parent-only', 'Run only parent tests') do
          @parent_only = true
        end
        
        opts.on('--children-only', 'Run only child tests') do
          @children_only = true
        end
        
        opts.on('--submodule NAME', 'Run tests for specific submodule') do |name|
          @specific_submodule = name
        end
        
        opts.on('-h', '--help', 'Display this help') do
          puts opts
          exit 0
        end
      end.parse!(@args)
    end

    def run_parent_tests
      puts "Parent Repository Tests:"
      
      if Dir.exist?('test')
        puts "  Running tests..."
        system('ruby -Ilib:test test/**/*_test.rb test/**/**/test_*.rb')
        
        if $?.success?
          puts "  ✓ All parent tests passed"
        else
          puts "  ✗ Some parent tests failed"
        end
      else
        puts "  ℹ No test directory found"
      end
      
      puts ""
    end

    def run_children_tests
      return unless File.exist?('.gitmodules')
      
      puts "Child Submodule Tests:"
      
      submodules = parse_gitmodules
      
      if submodules.empty?
        puts "  ℹ No child submodules found"
        return
      end
      
      submodules.each do |submodule|
        next if @specific_submodule && submodule[:name] != @specific_submodule
        run_submodule_tests(submodule)
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

    def run_submodule_tests(submodule)
      path = submodule[:path]
      name = submodule[:name]
      
      puts "  #{name}:"
      
      unless Dir.exist?(path)
        puts "    ✗ Directory does not exist: #{path}"
        return
      end
      
      Dir.chdir(path) do
        if Dir.exist?('test')
          puts "    Running tests..."
          system('ruby -Ilib:test test/**/*_test.rb test/**/**/test_*.rb')
          
          if $?.success?
            puts "    ✓ All tests passed"
          else
            puts "    ✗ Some tests failed"
          end
        else
          puts "    ℹ No test directory found"
        end
      end
    end
  end
end
