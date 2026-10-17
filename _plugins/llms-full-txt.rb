#!/usr/bin/env ruby
#
# Writes `/llms-full.txt`: the Markdown source of every published post
# concatenated into a single file, for LLMs and AI search engines that prefer
# full text over the curated index in `/llms.txt`.
#
# Implemented as a :post_write hook (rather than a generator) so that post
# bodies are copied verbatim from their source files and never re-processed by
# Liquid or kramdown.

module LlmsFullTxt
  FILENAME = "llms-full.txt"
  SEPARATOR = "=" * 78
  FRONT_MATTER = /\A---\s*\n.*?\n---\s*\n/m

  class << self
    def write(site)
      posts = site.posts.docs.reject { |doc| doc.data["hidden"] }
                   .sort_by(&:date).reverse

      content = header(site, posts) + posts.map { |post| entry(site, post) }.join

      File.write(File.join(site.dest, FILENAME), content)
      site.keep_files << FILENAME unless site.keep_files.include?(FILENAME)

      Jekyll.logger.info "#{FILENAME}:", "wrote #{posts.size} posts (#{content.bytesize} bytes)"
    end

    private

    def header(site, posts)
      <<~TXT
        # #{site.config['title']} — #{site.config.dig('social', 'name')}

        > #{site.config['description'].to_s.strip}

        Markdown source of every post on #{site.config['url']}, concatenated newest
        first. A curated index is available at #{site.config['url']}/llms.txt

        Author: #{site.config.dig('social', 'name')} (#{site.config.dig('social', 'email')})
        Generated: #{site.time.strftime('%Y-%m-%d')}
        Posts: #{posts.size}
      TXT
    end

    def entry(site, post)
      out = +"\n\n#{SEPARATOR}\n\n"
      out << "# #{post.data['title']}\n\n"
      out << "URL: #{site.config['url']}#{post.url}\n"
      out << "Date: #{post.date.strftime('%Y-%m-%d')}\n"

      categories = post.data["categories"]
      out << "Categories: #{categories.join(', ')}\n" if categories && !categories.empty?

      tags = post.data["tags"]
      out << "Tags: #{tags.join(', ')}\n" if tags && !tags.empty?

      description = post.data["description"].to_s.strip
      out << "Description: #{description}\n" unless description.empty?

      out << "\n" << markdown_body(post) << "\n"
    end

    # A post's body as written on disk, with the YAML front matter removed.
    # Falls back to the rendered content if the source file cannot be read.
    def markdown_body(post)
      File.read(post.path).sub(FRONT_MATTER, "").strip
    rescue StandardError => e
      Jekyll.logger.warn "#{FILENAME}:", "could not read #{post.path} (#{e.message})"
      post.content.strip
    end
  end
end

Jekyll::Hooks.register(:site, :post_write) { |site| LlmsFullTxt.write(site) }
