# frozen_string_literal: true

require 'fileutils'

module SubmodulerParent
  class SymlinkBuildCommand
    VENDOR_PARENT_STEERING = 'vendor/submoduler_parent/.kiro/steering'
    VENDOR_CHILD_STEERING = 'vendor/submoduler_child/.kiro/steering'
    PROJECT_STEERING = '.kiro/steering'

    def self.run
      new.run
    end

    def run
      puts "\n=== Building Symlinks (Parent) ==="
      ensure_directory_exists
      create_symlinks_from_vendor
      validate_symlinks
      report_results
    end

    private

    def ensure_directory_exists
      FileUtils.mkdir_p(PROJECT_STEERING) unless Dir.exist?(PROJECT_STEERING)
      puts "✓ Ensured #{PROJECT_STEERING} exists"
    end

    def create_symlinks_from_vendor
      @created = []
      @updated = []
      @skipped = []

      # Link from parent vendor gem
      link_files_from(VENDOR_PARENT_STEERING, '../../')
      
      # Link from child vendor gem
      link_files_from(VENDOR_CHILD_STEERING, '../../')
    end

    def link_files_from(source_dir, relative_prefix)
      unless Dir.exist?(source_dir)
        puts "⚠ Source directory not found: #{source_dir}"
        return
      end

      Dir.glob("#{source_dir}/*.md").each do |source_file|
        filename = File.basename(source_file)
        target = File.join(PROJECT_STEERING, filename)
        source_relative = File.join(relative_prefix, source_file)

        if File.symlink?(target)
          @updated << filename
          File.delete(target)
        elsif File.exist?(target)
          @skipped << filename
          next
        else
          @created << filename
        end

        File.symlink(source_relative, target)
      end
    end

    def validate_symlinks
      @broken = []
      
      Dir.glob("#{PROJECT_STEERING}/*.md").each do |link|
        next unless File.symlink?(link)
        unless File.exist?(link)
          @broken << File.basename(link)
        end
      end
    end

    def report_results
      puts "\n=== Symlink Build Results ==="
      puts "✓ Created: #{@created.length} files" if @created.any?
      @created.each { |f| puts "  + #{f}" } if @created.any?
      
      puts "↻ Updated: #{@updated.length} files" if @updated.any?
      @updated.each { |f| puts "  ↻ #{f}" } if @updated.any?
      
      puts "⊘ Skipped: #{@skipped.length} files (already exist)" if @skipped.any?
      @skipped.each { |f| puts "  ⊘ #{f}" } if @skipped.any?
      
      if @broken.any?
        puts "✗ Broken: #{@broken.length} symlinks"
        @broken.each { |f| puts "  ✗ #{f}" }
      end
      
      puts "\nTotal symlinks in #{PROJECT_STEERING}: #{Dir.glob("#{PROJECT_STEERING}/*.md").length}"
    end
  end
end
