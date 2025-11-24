# frozen_string_literal: true

require 'optparse'

module SubmodulerParent
  class PushCommand
    def initialize(args)
      @args = args
      @dry_run = false
      parse_options
    end

    def execute
      puts "Pushing changes to parent and child repositories..."
      puts ""
      
      # First push children
      push_children
      
      # Then push parent
      push_parent
      
      puts ""
      puts "✓ Push complete"
      0
    rescue StandardError => e
      puts "Error: #{e.message}"
      puts e.backtrace if ENV['DEBUG']
      1
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: bin/submoduler_parent.rb push [options]"
        
        opts.on('-n', '--dry-run', 'Show what would be pushed without actually pushing') do
          @dry_run = true
        end
        
        opts.on('-h', '--help', 'Display this help') do
          puts opts
          exit 0
        end
      end.parse!(@args)
    end

    def push_parent
      puts "Parent Repository:"
      
      # Check if there are commits to push
      ahead_count = `git rev-list @{u}..HEAD --count 2>/dev/null`.strip.to_i
      
      if ahead_count == 0
        puts "  ℹ No commits to push"
        return
      end
      
      puts "  → Pushing #{ahead_count} commit(s)..."
      
      if @dry_run
        puts "  [DRY RUN] Would push to origin"
      else
        output = `git push 2>&1`
        
        if $?.success?
          puts "  ✓ Pushed successfully"
        else
          puts "  ✗ Push failed:"
          output.each_line do |line|
            puts "    #{line.strip}"
          end
          raise "Failed to push parent repository"
        end
      end
      
      puts ""
    end

    def push_children
      return unless File.exist?('.gitmodules')
      
      submodules = parse_gitmodules
      
      if submodules.empty?
        puts "ℹ No child submodules found"
        puts ""
        return
      end
      
      puts "Child Submodules:"
      
      submodules.each do |submodule|
        push_submodule(submodule)
      end
      
      puts ""
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

    def push_submodule(submodule)
      path = submodule[:path]
      name = submodule[:name]
      
      puts "  #{name}:"
      
      unless Dir.exist?(path)
        puts "    ✗ Directory does not exist: #{path}"
        return
      end
      
      Dir.chdir(path) do
        # Check if there are commits to push
        ahead_count = `git rev-list @{u}..HEAD --count 2>/dev/null`.strip.to_i
        
        if ahead_count == 0
          puts "    ℹ No commits to push"
          return
        end
        
        puts "    → Pushing #{ahead_count} commit(s)..."
        
        if @dry_run
          puts "    [DRY RUN] Would push to origin"
        else
          output = `git push 2>&1`
          
          if $?.success?
            puts "    ✓ Pushed successfully"
          else
            puts "    ✗ Push failed:"
            output.each_line do |line|
              puts "      #{line.strip}"
            end
            # Don't raise, continue with other submodules
          end
        end
      end
    end
  end
end
