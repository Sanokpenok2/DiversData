# frozen_string_literal: true

require 'sequel'

module DiversBot
  module Models
    class ReportPhoto < Sequel::Model(:report_photos)
      PHOTO_TYPES = %w[density substrate additional].freeze

      many_to_one :report, class: 'DiversBot::Models::Report'
    end
  end
end
