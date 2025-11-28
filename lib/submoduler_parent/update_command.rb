# frozen_string_literal: true

require 'optparse'

module SubmodulerParent
  class UpdateCommand
    def initialize(args)
      @args = args
      @options = {}
      @failed_submodules = []
      @skipped_submodules = []
      @updated_submodules = []
      parse_options
    end

    def execute
      puts "=== Parent Update Workflow ==="
      puts ""
      
      submodules = get_submodules
      
      if submodules.empty?
        puts "No submodules found to update."
        return 0
      end
      
      puts "Found #{submodules.length} submodule(s) to update"
      puts ""
      
      submodules.each do |submodule|
        update_submodule(submodule)
      end
      
      display_summary
      
      @failed_submodules.empty? ? 0 : 1
    rescue StandardError => e
      puts "Error: #{e.message}"
      1
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: bin/submoduler update [options]"
        
        opts.on("--[no-]release", "Create GitHub releases for updated submodules") do |v|
          @options[:release] = v
        end
        
        opts.on("--only SUBMODULE", "Only update specified submodule") do |v|
          @options[:only] = v
        end
        
        opts.on("-h", "--help", "Show this help message") do
          puts opts
          exit 0
        end
      end.parse!(@args)
    end

    def get_submodules
      ini = SubmodulerCommon::SubmodulerIni.new
      return [] unless ini.exist?
      
      ini.load_config
      submodules = ini.submodules
      
      # Filter by --only option if specified
      if @options[:only]
        submodules.select! { |sm| sm[:name] == @options[:only] || sm[:path] == @options[:only] }
      end
      
      submodules
    rescue SubmodulerCommon::SubmodulerIni::ConfigError => e
      puts "Error reading configuration: #{e.message}"
      []
    end

    def update_submodule(submodule)
      path = submodule[:path]
      name = submodule[:name]
      
      puts "─" * 60
      puts "Updating: #{name}"
      puts "Path: #{path}"
      puts ""
      
      unless Dir.exist?(path)
        puts "✗ Directory does not exist: #{path}"
        @skipped_submodules << name
        return
      end
      
      # Check if it's a git repository (either .git directory or .git file for submodules)
      git_path = File.join(path, '.git')
      unless File.exist?(git_path)
        puts "✗ Not a git repository: #{path}"
        @skipped_submodules << name
        return
      end
      
      # Check if it has .submoduler.ini (is a child submodule)
      unless File.exist?(File.join(path, '.submoduler.ini'))
        puts "ℹ No .submoduler.ini found, skipping"
        @skipped_submodules << name
        return
      end
      
      # Run update command in submodule
      Dir.chdir(path) do
        # Calculate relative path to bin/submoduler from submodule
        depth = path.split('/').length
        relative_path = ('../' * depth) + 'bin/submoduler'
        
        # Build the command
        cmd = "#{relative_path} update"
        cmd += " --release" if @options[:release]
        
        puts "Running: #{cmd}"
        puts ""
        
        system(cmd)
        
        if $?.success?
          puts ""
          puts "✓ Successfully updated #{name}"
          @updated_submodules << name
        else
          puts ""
          puts "✗ Failed to update #{name}"
          @failed_submodules << name
        end
      end
      
      puts ""
    rescue StandardError => e
      puts "✗ Error updating #{name}: #{e.message}"
      @failed_submodules << name
    end

    def display_summary
      puts "=" * 60
      puts "Update Summary"
      puts "=" * 60
      puts ""
      
      if @updated_submodules.any?
        puts "✓ Updated (#{@updated_submodules.length}):"
        @updated_submodules.each { |name| puts "  - #{name}" }
        puts ""
      end
      
      if @skipped_submodules.any?
        puts "⊘ Skipped (#{@skipped_submodules.length}):"
        @skipped_submodules.each { |name| puts "  - #{name}" }
        puts ""
      end
      
      if @failed_submodules.any?
        puts "✗ Failed (#{@failed_submodules.length}):"
        @failed_submodules.each { |name| puts "  - #{name}" }
        puts ""
      end
      
      total = @updated_submodules.length + @skipped_submodules.length + @failed_submodules.length
      puts "Total: #{total} submodule(s) processed"
    end
  end
end
