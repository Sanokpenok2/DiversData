# frozen_string_literal: true

require 'sequel'

module DiversBot
  module Models
    class UserSession < Sequel::Model(:user_sessions)
      STATES = %w[
        idle
        waiting_date
        waiting_location_choice
        waiting_map_location
        waiting_coordinates
        waiting_text_location
        waiting_encounter_type
        waiting_encounter_radius
        waiting_depth
        waiting_depth_precision
        waiting_density_photos
        waiting_substrate_type
        waiting_substrate_photo
        waiting_additional_info
        waiting_extra_photos
      ].freeze

      def self.find_or_create_for(user)
        record = find(max_user_id: user.id)
        return record if record

        create(
          max_user_id: user.id,
          state: 'idle',
          data: {},
          created_at: Time.now,
          updated_at: Time.now
        )
      end

      def transition_to!(state, data_updates = {})
        raise ArgumentError, "Unknown state: #{state}" unless STATES.include?(state)

        merged = merge_data(data || {}, data_updates)
        persist!(state: state, data: merged)
      end

      def append_photo!(attachment_token:, photo_type:, caption: nil, source_url: nil)
        raise ArgumentError, 'attachment_token required' if attachment_token.to_s.empty?

        current = normalize_data(data || {})
        photos = Array(current['photos'])
        photos << {
          'attachment_token' => attachment_token.to_s,
          'photo_type' => photo_type.to_s,
          'source_url' => source_url&.to_s,
          'caption' => caption
        }.compact

        current['photos'] = photos
        persist!(data: current)
        photos
      end

      def track_message_id!(message_id)
        return unless message_id

        mid = message_id.to_s
        current = normalize_data(data || {})
        ids = Array(current['chat_message_ids'])
        return if ids.include?(mid)

        ids << mid
        current['chat_message_ids'] = ids.last(300)
        persist!(data: current)
      end

      def remember_chat_id!(chat_id)
        return unless chat_id

        current = normalize_data(data || {})
        return if current['max_chat_id'].to_s == chat_id.to_s

        current['max_chat_id'] = chat_id.to_s
        persist!(data: current)
      end

      def stored_chat_id
        draft_data['max_chat_id']
      end

      def reset!
        persist!(state: 'idle', data: {})
      end

      def draft_data
        normalize_data(data || {})
      end

      def normalize_data(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, val), result|
            result[key.to_s] = normalize_data(val)
          end
        when Array
          value.map { |item| normalize_data(item) }
        else
          value
        end
      end

      def merge_data(current, updates)
        normalize_data(current).merge(normalize_data(updates))
      end

      def persist!(data:, state: nil)
        normalized = normalize_data(data)
        updates = {
          data: Sequel.pg_jsonb(normalized),
          updated_at: Time.now
        }
        updates[:state] = state if state

        db[:user_sessions].where(id: id).update(updates)
        refresh
      end
    end
  end
end
