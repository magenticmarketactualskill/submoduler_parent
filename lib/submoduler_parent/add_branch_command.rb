# frozen_string_literal: true

require 'optparse'

module SubmodulerParent
  class AddBranchCommand
    def initialize(args)
      @args = args
      @dry_run = false
      @checkout = false
      @branch_name = nil
      parse_options
    end

    def execute
      unless @branch_name
        puts "Error: Branch name is required"
        puts "Usage: bin/submoduler add_branch <branch_name> [options]"
        return 1
      end

      puts "Creating branch '#{@branch_name}' across all repositories..."
      puts ""

      results = { created: [], existed: [], failed: [] }

      # Create in children first
      create_branch_in_children(results)

      # Create in vendor repos
      create_branch_in_vendors(results)

      # Create in parent last
      create_branch_in_parent(results)

      # Summary
      puts ""
      puts "Summary:"
      puts "  ✓ Created: #{results[:created].length}" unless results[:created].empty?
      puts "  ℹ Already existed: #{results[:existed].length}" unless results[:existed].empty?
      puts "  ✗ Failed: #{results[:failed].length}" unless results[:failed].empty?
      puts ""

      if @checkout && !@dry_run
        puts "All repositories are now on branch '#{@branch_name}'"
      end

      results[:failed].empty? ? 0 : 1
    rescue StandardError => e
      puts "Error: #{e.message}"
      puts e.backtrace if ENV['DEBUG']
      1
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: bin/submoduler add_branch <branch_name> [options]"

        opts.on('-n', '--dry-run', 'Show what would be done without actually doing it') do
          @dry_run = true
        end

        opts.on('-c', '--checkout', 'Checkout the branch after creating it') do
          @checkout = true
        end

        opts.on('-h', '--help', 'Display this help') do
          puts opts
          exit 0
        end
      end.parse!(@args)

      @branch_name = @args.shift
    end

    def create_branch_in_parent(results)
      puts "Parent Repository:"
      create_branch_in_repo('.', 'parent', results)
      puts ""
    end

    def create_branch_in_children(results)
      return unless File.exist?('.gitmodules')

      submodules = parse_gitmodules

      if submodules.empty?
        puts "ℹ No child submodules found"
        puts ""
        return
      end

      puts "Child Submodules:"

      submodules.each do |submodule|
        create_branch_in_repo(submodule[:path], submodule[:name], results)
      end

      puts ""
    end

    def create_branch_in_vendors(results)
      return unless Dir.exist?('vendor')

      vendor_repos = find_vendor_repos

      return if vendor_repos.empty?

      puts "Vendor Repositories:"

      vendor_repos.each do |repo|
        create_branch_in_repo(repo[:path], repo[:name], results)
      end

      puts ""
    end

    def find_vendor_repos
      repos = []
      Dir.glob('vendor/*').each do |path|
        next unless File.directory?(path)
        next unless Dir.exist?(File.join(path, '.git'))

        repos << { name: File.basename(path), path: path }
      end
      repos
    end

    def create_branch_in_repo(path, name, results)
      puts "  #{name}:"

      unless Dir.exist?(path)
        puts "    ✗ Directory does not exist: #{path}"
        results[:failed] << name
        return
      end

      Dir.chdir(path) do
        # Check if branch already exists
        existing = `git branch --list #{@branch_name} 2>/dev/null`.strip
        remote_existing = `git branch -r --list origin/#{@branch_name} 2>/dev/null`.strip

        if !existing.empty?
          puts "    ℹ Branch already exists locally"
          results[:existed] << name

          if @checkout
            checkout_branch
          end
          return
        end

        if !remote_existing.empty?
          puts "    ℹ Branch exists on remote, tracking..."
          if @dry_run
            puts "    [DRY RUN] Would create tracking branch"
          else
            output = `git checkout -b #{@branch_name} --track origin/#{@branch_name} 2>&1`
            if $?.success?
              puts "    ✓ Created tracking branch"
              results[:created] << name
            else
              puts "    ✗ Failed to create tracking branch:"
              output.each_line { |line| puts "      #{line.strip}" }
              results[:failed] << name
            end
          end
          return
        end

        # Create new branch
        if @dry_run
          puts "    [DRY RUN] Would create branch '#{@branch_name}'"
          results[:created] << name
        else
          # Create branch from current HEAD
          output = `git branch #{@branch_name} 2>&1`

          if $?.success?
            puts "    ✓ Created branch '#{@branch_name}'"
            results[:created] << name

            if @checkout
              checkout_branch
            end
          else
            puts "    ✗ Failed to create branch:"
            output.each_line { |line| puts "      #{line.strip}" }
            results[:failed] << name
          end
        end
      end
    end

    def checkout_branch
      output = `git checkout #{@branch_name} 2>&1`
      if $?.success?
        puts "    ✓ Checked out '#{@branch_name}'"
      else
        puts "    ✗ Failed to checkout:"
        output.each_line { |line| puts "      #{line.strip}" }
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
  end
end
