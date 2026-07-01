# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require 'uri'
require 'faraday'

module DiversBot
  module Services
    module PhotoStorage
      module_function

      def root
        @root ||= begin
          path = ENV.fetch('REPORT_PHOTOS_STORAGE') do
            File.expand_path('../../../../storage/report_photos', __dir__)
          end
          FileUtils.mkdir_p(path)
          path
        end
      end

      def store_from_url(source_url, report_id:, photo_type:)
        return nil if source_url.to_s.strip.empty?

        response = download(source_url)
        return nil unless response&.success?

        ext = extension_for(response, source_url)
        filename = "#{report_id}_#{photo_type}_#{SecureRandom.hex(8)}#{ext}"
        absolute = File.join(root, filename)
        File.binwrite(absolute, response.body)
        filename
      rescue StandardError => e
        warn "[WARN] PhotoStorage.store_from_url failed: #{e.message}"
        nil
      end

      def download(url)
        Faraday.get(url) do |req|
          req.options.timeout = 30
          req.options.open_timeout = 10
        end
      rescue Faraday::Error => e
        warn "[WARN] PhotoStorage download failed: #{e.message}"
        nil
      end

      def extension_for(response, url)
        type = response.headers['content-type'].to_s.split(';', 2).first.strip.downcase
        case type
        when 'image/jpeg', 'image/jpg' then '.jpg'
        when 'image/png' then '.png'
        when 'image/gif' then '.gif'
        when 'image/webp' then '.webp'
        when 'image/heic' then '.heic'
        else
          ext = File.extname(URI.parse(url.to_s).path.to_s)
          ext.empty? ? '.jpg' : ext
        end
      rescue StandardError
        '.jpg'
      end
    end
  end
end
