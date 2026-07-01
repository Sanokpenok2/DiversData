# frozen_string_literal: true

require 'json'

module DiversBot
  module Messenger
    User = Struct.new(:id, :username, :first_name, :last_name, keyword_init: true)
    Chat = Struct.new(:id, keyword_init: true)
    Location = Struct.new(:latitude, :longitude, keyword_init: true)
    WebAppData = Struct.new(:data, keyword_init: true)

    # Wraps a MAX update into a Telegram-like interface for the conversation flow.
    class IncomingMessage
      def self.from_update(update)
        case update[:update_type]
        when 'message_created'
          new(update)
        when 'bot_started'
          from_bot_started(update)
        end
      end

      def self.from_bot_started(update)
        msg = allocate
        msg.instance_variable_set(:@update, update)
        msg.instance_variable_set(:@bot_started, true)
        msg
      end

      def initialize(update)
        @update = update
        @bot_started = false
      end

      def bot_started?
        @bot_started
      end

      def from
        if bot_started?
          user_hash = @update[:user] || {}
          build_user(user_hash)
        else
          sender = message&.dig(:sender) || {}
          build_user(sender)
        end
      end

      def chat
        Chat.new(id: chat_id)
      end

      def chat_id
        if bot_started?
          @update[:chat_id]
        else
          message.dig(:recipient, :chat_id) ||
            message.dig(:recipient, :id) ||
            @update[:chat_id]
        end
      end

      def raw_message
        @update[:message]
      end

      def text
        return '/start' if bot_started?

        message.dig(:body, :text)&.strip
      end

      def message_id
        return nil if bot_started?

        message.dig(:body, :mid)
      end

      def location
        attachment = attachments.find { |a| a[:type] == 'location' || a['type'] == 'location' }
        return nil unless attachment

        lat = attachment[:latitude] || attachment['latitude'] ||
              attachment.dig(:payload, :latitude) || attachment.dig('payload', 'latitude')
        lon = attachment[:longitude] || attachment['longitude'] ||
              attachment.dig(:payload, :longitude) || attachment.dig('payload', 'longitude')
        return nil unless lat && lon

        Location.new(latitude: lat.to_f, longitude: lon.to_f)
      end

      def web_app_data
        attachment = attachments.find do |a|
          type = (a[:type] || a['type']).to_s
          type.include?('share') || type.include?('app') || type == 'payload'
        end

        raw = if attachment
                attachment.dig(:payload, :data) || attachment.dig('payload', 'data') ||
                  attachment.dig(:payload, :text) || attachment.dig('payload', 'text') ||
                  attachment[:payload] || attachment['payload']
              end
        raw ||= text if text&.start_with?('{')

        return nil unless raw

        data = raw.is_a?(Hash) ? raw : JSON.parse(raw.to_s)
        return WebAppData.new(data: data.to_json) if data.is_a?(Hash) && (data.key?('lat') || data.key?(:lat))

        nil
      rescue JSON::ParserError
        nil
      end

      def photo_message?
        img = image_attachment
        img.present?
      end

      def photo_attachment_token
        image_attachment&.dig(:token)
      end

      def photo_attachment_url
        image_attachment&.dig(:url)
      end

      def image_attachment
        image = attachments.find { |a| (a[:type] || a['type']) == 'image' }
        return nil unless image

        payload = image[:payload] || image['payload'] || {}
        token = (payload[:token] || payload['token']).presence
        url = (payload[:url] || payload['url']).presence

        unless token || url
          photos = payload[:photos] || payload['photos']
          photo_entries(photos).each do |photo|
            token ||= (photo[:token] || photo['token']).presence
            url ||= (photo[:url] || photo['url']).presence
          end
        end

        return nil unless token || url

        { token: token, url: url }.compact
      end

      def photo_entries(photos)
        case photos
        when Hash
          photos.values
        when Array
          photos
        else
          []
        end
      end

      def caption
        text unless bot_started?
      end

      private

      def message
        @update[:message]
      end

      def attachments
        Array(message&.dig(:body, :attachments))
      end

      def build_user(hash)
        user_id = hash[:user_id] || hash['user_id']
        name = hash[:name] || hash['name'] || ''
        parts = name.to_s.split(/\s+/, 2)

        User.new(
          id: user_id,
          username: hash[:username] || hash['username'],
          first_name: parts[0],
          last_name: parts[1]
        )
      end
    end
  end
end
