# frozen_string_literal: true

require 'sequel'

module DiversBot
  module Models
    class Report < Sequel::Model(:reports)
      one_to_many :photos, class: 'DiversBot::Models::ReportPhoto', key: :report_id

      LOCATION_TYPES = %w[map_point coordinates text_description].freeze
      ENCOUNTER_TYPES = %w[single multiple_in_radius].freeze

      def self.create_from_draft!(user, draft)
        report = create(
          telegram_user_id: user.id,
          telegram_username: user.username,
          telegram_first_name: user.first_name,
          telegram_last_name: user.last_name,
          observation_date: draft.fetch('observation_date'),
          location_type: draft.fetch('location_type'),
          latitude: draft['latitude'],
          longitude: draft['longitude'],
          location_description: draft['location_description'],
          encounter_type: draft.fetch('encounter_type'),
          encounter_radius_m: draft['encounter_radius_m'],
          depth_m: draft.fetch('depth_m'),
          depth_is_approximate: draft.fetch('depth_is_approximate', true),
          substrate_type: draft.fetch('substrate_type'),
          additional_info: draft['additional_info'],
          status: 'submitted',
          created_at: Time.now,
          updated_at: Time.now
        )

        Array(draft['photos']).each do |photo|
          Models::ReportPhoto.create(
            report_id: report.id,
            telegram_file_id: photo.fetch('file_id'),
            photo_type: photo.fetch('photo_type'),
            caption: photo['caption'],
            created_at: Time.now
          )
        end

        report
      end
    end
  end
end
