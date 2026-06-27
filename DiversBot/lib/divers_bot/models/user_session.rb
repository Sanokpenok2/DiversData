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
        record = find(telegram_user_id: user.id)
        return record if record

        create(
          telegram_user_id: user.id,
          state: 'idle',
          data: {},
          created_at: Time.now,
          updated_at: Time.now
        )
      end

      def transition_to!(state, data_updates = {})
        raise ArgumentError, "Unknown state: #{state}" unless STATES.include?(state)

        merged = (data || {}).merge(data_updates)
        update(state: state, data: merged, updated_at: Time.now)
      end

      def reset!
        update(state: 'idle', data: {}, updated_at: Time.now)
      end

      def draft_data
        data || {}
      end
    end
  end
end
