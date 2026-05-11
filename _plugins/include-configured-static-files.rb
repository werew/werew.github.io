#!/usr/bin/env ruby

require "find"

Jekyll::Hooks.register :site, :post_read do |site|
  static_asset_dirs = Array(site.config["static_asset_dirs"]).map(&:to_s).reject(&:empty?)
  next if static_asset_dirs.empty?

  existing_files = site.static_files.each_with_object({}) do |file, files|
    files[file.relative_path] = true
  end

  static_asset_dirs.each do |dir|
    source_dir = site.in_source_dir(dir)
    next unless Dir.exist?(source_dir)

    Find.find(source_dir) do |path|
      next if File.directory?(path)

      relative_path = path.delete_prefix("#{site.source}/")
      relative_dir = File.dirname(relative_path)
      filename = File.basename(relative_path)
      logical_path = File.join("/", relative_dir, filename)

      next if existing_files[logical_path]

      site.static_files << Jekyll::StaticFile.new(site, site.source, "/#{relative_dir}", filename)
      existing_files[logical_path] = true
    end
  end
end
