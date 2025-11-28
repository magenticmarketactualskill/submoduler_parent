# frozen_string_literal: true

require 'optparse'

module SubmodulerParent
  class SyncVersionCommand
    def initialize(args)
      @args = args
      @options = {}
      @submodule_versions = {}
      parse_options
    end

    def execute
      puts "=== Syncing Versions Across Submodules ==="
      puts ""
      
      submodules = get_submodules
      
      if submodules.empty?
        puts "No submodules found."
        return 0
      end
      
      # Collect versions from all submodules
      collect_versions(submodules)
      
      # Find highest version
      highest_version = find_highest_version
      
      if highest_version.nil?
        puts "No versions found in submodules."
        return 1
      end
      
      puts ""
      puts "Highest version found: #{highest_version}"
      puts ""
      
      # Set all submodules to highest version
      sync_to_version(submodules, highest_version)
      
      display_summary
      
      0
    rescue StandardError => e
      puts "Error: #{e.message}"
      puts e.backtrace if @options[:verbose]
      1
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: bin/submoduler sync_version [options]"
        
        opts.on("--dry-run", "Show what would be done without making changes") do
          @options[:dry_run] = true
        end
        
        opts.on("-v", "--verbose", "Show detailed output") do
          @options[:verbose] = true
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
      ini.submodules
    rescue SubmodulerCommon::SubmodulerIni::ConfigError => e
      puts "Error reading configuration: #{e.message}"
      []
    end

    def collect_versions(submodules)
      puts "Collecting versions from submodules..."
      puts ""
      
      submodules.each do |submodule|
        path = submodule[:path]
        name = submodule[:name]
        
        # Skip if not a child submodule
        unless has_submoduler_ini?(path)
          puts "  ⊘ #{name}: No .submoduler.ini (skipping)"
          next
        end
        
        version = get_submodule_version(path)
        
        if version
          @submodule_versions[name] = { path: path, version: version }
          puts "  ✓ #{name}: #{version}"
        else
          puts "  ⊘ #{name}: No version file found"
        end
      end
    end

    def has_submoduler_ini?(path)
      File.exist?(File.join(path, '.submoduler.ini'))
    end

    def get_submodule_version(path)
      # Look for version.rb file
      version_file = find_version_file(path)
      return nil unless version_file
      
      extract_version(version_file)
    end

    def find_version_file(path)
      # Common patterns for version files
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

    def extract_version(file_path)
      content = File.read(file_path)
      
      # Match VERSION = "x.y.z" pattern
      if content =~ /VERSION\s*=\s*["']([^"']+)["']/
        $1
      else
        nil
      end
    rescue StandardError => e
      puts "  Warning: Error reading #{file_path}: #{e.message}" if @options[:verbose]
      nil
    end

    def find_highest_version
      return nil if @submodule_versions.empty?
      
      versions = @submodule_versions.values.map { |v| v[:version] }
      
      # Sort versions (semantic versioning)
      versions.max_by { |v| version_to_comparable(v) }
    end

    def version_to_comparable(version)
      # Convert "1.2.3" to [1, 2, 3] for comparison
      version.split('.').map(&:to_i)
    end

    def sync_to_version(submodules, target_version)
      if @options[:dry_run]
        puts "DRY RUN: Would sync the following submodules to #{target_version}:"
        puts ""
      else
        puts "Syncing submodules to version #{target_version}..."
        puts ""
      end
      
      @synced = []
      @skipped = []
      @failed = []
      
      submodules.each do |submodule|
        path = submodule[:path]
        name = submodule[:name]
        
        # Skip if no version info
        unless @submodule_versions.key?(name)
          @skipped << name
          next
        end
        
        current_version = @submodule_versions[name][:version]
        
        # Skip if already at target version
        if current_version == target_version
          puts "  ✓ #{name}: Already at #{target_version}"
          @skipped << name
          next
        end
        
        if @options[:dry_run]
          puts "  → #{name}: #{current_version} → #{target_version}"
          @synced << name
        else
          if set_submodule_version(path, name, target_version)
            puts "  ✓ #{name}: #{current_version} → #{target_version}"
            @synced << name
          else
            puts "  ✗ #{name}: Failed to update"
            @failed << name
          end
        end
      end
    end

    def set_submodule_version(path, name, version)
      version_file = find_version_file(path)
      return false unless version_file
      
      begin
        content = File.read(version_file)
        
        # Replace VERSION = "old" with VERSION = "new"
        new_content = content.gsub(
          /(VERSION\s*=\s*["'])([^"']+)(["'])/,
          "\\1#{version}\\3"
        )
        
        File.write(version_file, new_content)
        
        # Commit the change
        Dir.chdir(path) do
          # Get the relative path from the submodule root
          relative_version_file = version_file.sub("#{path}/", '')
          system("git add #{relative_version_file}")
          system("git commit -m 'Sync version to #{version}'")
        end
        
        true
      rescue StandardError => e
        puts "    Error: #{e.message}" if @options[:verbose]
        false
      end
    end

    def display_summary
      puts ""
      puts "=" * 60
      puts "Sync Summary"
      puts "=" * 60
      puts ""
      
      if @options[:dry_run]
        puts "DRY RUN - No changes were made"
        puts ""
      end
      
      if @synced.any?
        puts "✓ Synced (#{@synced.length}):"
        @synced.each { |name| puts "  - #{name}" }
        puts ""
      end
      
      if @skipped.any?
        puts "⊘ Skipped (#{@skipped.length}):"
        @skipped.each { |name| puts "  - #{name}" }
        puts ""
      end
      
      if @failed.any?
        puts "✗ Failed (#{@failed.length}):"
        @failed.each { |name| puts "  - #{name}" }
        puts ""
      end
      
      total = @synced.length + @skipped.length + @failed.length
      puts "Total: #{total} submodule(s) processed"
    end
  end
end
