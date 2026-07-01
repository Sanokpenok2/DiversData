# frozen_string_literal: true

class ReportPhoto < ApplicationRecord
  self.table_name = "report_photos"
  self.record_timestamps = false

  PHOTO_TYPES = {
    "density" => "Плотность поселения",
    "substrate" => "Субстрат",
    "additional" => "Дополнительное фото"
  }.freeze

  belongs_to :report, inverse_of: :photos

  def type_label
    PHOTO_TYPES.fetch(photo_type, photo_type)
  end
end
