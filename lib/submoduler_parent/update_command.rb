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
      @parent_update_success = false
      parse_options
    end

    def execute
      puts "=== Parent Update Workflow ==="
      puts ""
      
      # Update submodules first
      submodules = get_submodules
      
      if submodules.empty?
        puts "No submodules found to update."
      else
        puts "Found #{submodules.length} submodule(s) to update"
        puts ""
        
        submodules.each do |submodule|
          update_submodule(submodule)
        end
      end
      
      # Update parent repository (unless skipped)
      unless @options[:skip_parent]
        update_parent
      else
        puts "⊘ Skipping parent repository update"
        @parent_update_success = true
      end
      
      display_summary
      
      @failed_submodules.empty? && @parent_update_success ? 0 : 1
    rescue StandardError => e
      puts "Error: #{e.message}"
      1
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: bin/submoduler update [options]"
        
        opts.on("-m", "--message MESSAGE", "Commit message (required)") do |v|
          @options[:message] = v
        end
        
        opts.on("--[no-]release", "Create GitHub releases for updated submodules") do |v|
          @options[:release] = v
        end
        
        opts.on("--only SUBMODULE", "Only update specified submodule") do |v|
          @options[:only] = v
        end
        
        opts.on("--skip-parent", "Skip updating the parent repository") do
          @options[:skip_parent] = true
        end
        
        opts.on("-h", "--help", "Show this help message") do
          puts opts
          exit 0
        end
      end.parse!(@args)
      
      # Validate required options
      unless @options[:message] || @options[:skip_parent]
        puts "Error: --message (-m) is required unless --skip-parent is specified"
        puts "Usage: bin/submoduler update -m 'commit message' [options]"
        exit 1
      end
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
        cmd += " -m '#{@options[:message]}'" if @options[:message]
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

    def update_parent
      puts "─" * 60
      puts "Updating: Parent Repository"
      puts ""
      
      # Check if there are any changes
      status_output = `git status --porcelain`
      
      if status_output.strip.empty?
        puts "ℹ No changes in parent repository"
        @parent_update_success = true
        return
      end
      
      # Run tests if available
      if run_parent_tests
        puts "✓ Tests passed"
      else
        puts "⚠ No tests found or tests failed"
      end
      
      # Stage and commit changes
      puts "Staging changes..."
      system("git add .")
      
      puts "Committing changes..."
      message = @options[:message] || generate_commit_message
      system("git commit -m '#{message}'")
      
      if $?.success?
        puts "✓ Changes committed"
        
        # Push changes
        puts "Pushing changes to remote..."
        system("git push")
        
        if $?.success?
          puts "✓ Changes pushed"
          @parent_update_success = true
        else
          puts "⚠ Failed to push changes"
          @parent_update_success = false
        end
      else
        puts "✗ Failed to commit changes"
        @parent_update_success = false
      end
      
      puts ""
    rescue StandardError => e
      puts "✗ Error updating parent: #{e.message}"
      @parent_update_success = false
    end

    def run_parent_tests
      # Check for common test directories/files
      if Dir.exist?('test')
        puts "Running tests..."
        system("ruby -Ilib:test -e 'Dir.glob(\"test/**/*test*.rb\").each { |f| require_relative f }'")
        return $?.success?
      elsif Dir.exist?('spec')
        puts "Running tests..."
        system("bundle exec rspec")
        return $?.success?
      end
      
      false
    end

    def generate_commit_message
      # Get parent version
      parent_version = get_parent_version
      
      # Get highest child version
      child_version = get_highest_child_version
      
      # Build commit message
      parts = []
      parts << "Bump parent version to #{parent_version}" if parent_version
      parts << "Bump child version to #{child_version}" if child_version
      parts << "update scripts"
      
      parts.join('. ')
    end

    def get_parent_version
      # Look for version file in parent
      version_file = find_parent_version_file
      return nil unless version_file
      
      extract_version_from_file(version_file)
    end

    def find_parent_version_file
      # Common patterns for version files in parent
      patterns = [
        "lib/**/version.rb",
        "lib/*/version.rb"
      ]
      
      patterns.each do |pattern|
        files = Dir.glob(pattern)
        return files.first if files.any?
      end
      
      nil
    end

    def get_highest_child_version
      return nil if @updated_submodules.empty?
      
      versions = []
      
      @updated_submodules.each do |name|
        # Find the submodule info
        submodule = get_submodules.find { |sm| sm[:name] == name }
        next unless submodule
        
        version = get_submodule_version(submodule[:path])
        versions << version if version
      end
      
      return nil if versions.empty?
      
      # Return highest version
      versions.max_by { |v| version_to_comparable(v) }
    end

    def get_submodule_version(path)
      version_file = find_submodule_version_file(path)
      return nil unless version_file
      
      extract_version_from_file(version_file)
    end

    def find_submodule_version_file(path)
      patterns = [
        "#{path}/lib/**/version.rb",
        "#{path}/lib/*/version.rb"
      ]
      
      patterns.each do |pattern|
        files = Dir.glob(pattern)
        return files.first if files.any?
      end
      
      nil
    end

    def extract_version_from_file(file_path)
      content = File.read(file_path)
      
      # Match VERSION = "x.y.z" pattern
      if content =~ /VERSION\s*=\s*["']([^"']+)["']/
        $1
      else
        nil
      end
    rescue StandardError
      nil
    end

    def version_to_comparable(version)
      # Convert "1.2.3" to [1, 2, 3] for comparison
      version.split('.').map(&:to_i)
    end

    def display_summary
      puts "=" * 60
      puts "Update Summary"
      puts "=" * 60
      puts ""
      
      if @parent_update_success
        puts "✓ Parent repository updated"
        puts ""
      elsif @parent_update_success == false
        puts "✗ Parent repository update failed"
        puts ""
      end
      
      if @updated_submodules.any?
        puts "✓ Updated submodules (#{@updated_submodules.length}):"
        @updated_submodules.each { |name| puts "  - #{name}" }
        puts ""
      end
      
      if @skipped_submodules.any?
        puts "⊘ Skipped submodules (#{@skipped_submodules.length}):"
        @skipped_submodules.each { |name| puts "  - #{name}" }
        puts ""
      end
      
      if @failed_submodules.any?
        puts "✗ Failed submodules (#{@failed_submodules.length}):"
        @failed_submodules.each { |name| puts "  - #{name}" }
        puts ""
      end
      
      total = @updated_submodules.length + @skipped_submodules.length + @failed_submodules.length
      puts "Total: #{total} submodule(s) processed"
    end
  end
end
