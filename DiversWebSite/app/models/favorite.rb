# frozen_string_literal: true

class Favorite < ApplicationRecord
  belongs_to :scientist
  belongs_to :report

  validates :report_id, uniqueness: { scope: :scientist_id }
end
