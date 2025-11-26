require 'feedjira'
require 'httparty'
require 'jekyll'
require 'uri'

module ExternalPosts
  class ExternalPostsGenerator < Jekyll::Generator
    safe true
    priority :high

    def generate(site)
      sources = site.config['external_sources']
      return if sources.nil? || !sources.respond_to?(:each)

      sources.each do |src|
        name = src['name'] || 'unknown'
        url  = src['rss_url']

        unless url && valid_uri?(url)
          Jekyll.logger.warn('ExternalPosts', "Skip '#{name}': invalid rss_url '#{url}'")
          next
        end

        Jekyll.logger.info('ExternalPosts', "Fetching external posts from #{name} (#{url})")

        begin
          response = HTTParty.get(
            url,
            headers: { 'User-Agent' => 'al-folio-external-posts (+https://github.com/alshedivat/al-folio)' },
            timeout: 15
          )

          if response.code != 200
            Jekyll.logger.warn('ExternalPosts', "Skip '#{name}': HTTP #{response.code}")
            next
          end

          body = (response.body || '').dup
          if body.strip.empty?
            Jekyll.logger.warn('ExternalPosts', "Skip '#{name}': empty response body")
            next
          end

          # Quick content sniffing to ensure it's XML feed-like
          content_type = response.headers && response.headers['content-type']
          looks_like_xml = !!(content_type && content_type.include?('xml')) || body.include?('<rss') || body.include?('<feed')
          unless looks_like_xml
            Jekyll.logger.warn('ExternalPosts', "Skip '#{name}': response is not XML/feed")
            next
          end

          xml = body.force_encoding('UTF-8')
          feed = Feedjira.parse(xml)

          unless feed && feed.respond_to?(:entries)
            Jekyll.logger.warn('ExternalPosts', "Skip '#{name}': parsed feed has no entries")
            next
          end

          entries = feed.entries || []
          # Optional per-source limit to avoid flooding (default: all)
          limit = (src['limit'].to_i if src['limit']).to_i
          entries = entries.first(limit) if limit > 0

          entries.each do |e|
            Jekyll.logger.info('ExternalPosts', ".. include #{e.url}")
            title = (e.title || 'untitled').to_s
            slug = title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
            path = site.in_source_dir("_posts/#{slug}.md")

            doc = Jekyll::Document.new(
              path,
              { site: site, collection: site.collections['posts'] }
            )

            doc.data['external_source'] = name
            doc.data['feed_content']    = e.respond_to?(:content) ? e.content : nil
            doc.data['title']           = title
            doc.data['description']     = e.respond_to?(:summary) ? e.summary : nil
            doc.data['date']            = e.respond_to?(:published) ? e.published : nil
            doc.data['redirect']        = e.respond_to?(:url) ? e.url : nil

            site.collections['posts'].docs << doc
          end

        rescue Feedjira::NoParserAvailable => e
          Jekyll.logger.warn('ExternalPosts', "Skip '#{name}': Feed parsing error (#{e.class}: #{e.message})")
          next
        rescue StandardError => e
          Jekyll.logger.warn('ExternalPosts', "Skip '#{name}': #{e.class} - #{e.message}")
          next
        end
      end
    end

    private
    def valid_uri?(str)
      uri = URI.parse(str)
      %w[http https].include?(uri.scheme) && !uri.host.nil?
    rescue URI::InvalidURIError
      false
    end
  end

end
