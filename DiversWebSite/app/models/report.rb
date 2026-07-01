# frozen_string_literal: true

class Report < ApplicationRecord
  self.table_name = "reports"

  has_many :photos, class_name: "ReportPhoto", foreign_key: :report_id, dependent: :destroy, inverse_of: :report
  has_many :favorites, dependent: :destroy
  has_many :deletion_requests, class_name: "ReportDeletionRequest", dependent: :destroy

  LOCATION_TYPES = {
    "map_point" => "Точка на карте",
    "coordinates" => "Координаты",
    "text_description" => "Текстовое описание"
  }.freeze

  ENCOUNTER_TYPES = {
    "single" => "Единичная встреча",
    "multiple_in_radius" => "Множественная встреча"
  }.freeze

  scope :with_coordinates, -> { where.not(latitude: nil, longitude: nil) }
  scope :without_coordinates, -> { where(latitude: nil).or(where(longitude: nil)) }
  scope :text_description, -> { submitted.where(location_type: "text_description") }
  scope :submitted, -> { where(status: "submitted") }
  scope :recent_first, -> { order(observation_date: :desc, id: :desc) }

  scope :filtered, lambda { |params|
    scope = all
    scope = scope.where("observation_date >= ?", params[:date_from]) if params[:date_from].present?
    scope = scope.where("observation_date <= ?", params[:date_to]) if params[:date_to].present?
    scope = scope.where(encounter_type: params[:encounter_type]) if params[:encounter_type].present?
    scope = scope.where(location_type: params[:location_type]) if params[:location_type].present?
    scope = scope.where("depth_m >= ?", params[:depth_min]) if params[:depth_min].present?
    scope = scope.where("depth_m <= ?", params[:depth_max]) if params[:depth_max].present?
    scope = scope.where(id: params[:report_ids]) if params[:report_ids].present?
    scope = scope.where(id: params[:report_id]) if params[:report_id].present?
    scope
  }

  def mappable?
    latitude.present? && longitude.present?
  end

  def location_label
    LOCATION_TYPES.fetch(location_type, location_type)
  end

  def encounter_label
    ENCOUNTER_TYPES.fetch(encounter_type, encounter_type)
  end

  def depth_label
    precision = depth_is_approximate ? "приблизительная" : "точная"
    "#{depth_m.to_i == depth_m ? depth_m.to_i : depth_m} м (#{precision})"
  end

  def reporter_name
    [max_first_name, max_last_name].compact.join(" ").presence || max_username || "Дайвер ##{max_user_id}"
  end

  def coordinates_label
    return location_description if location_type == "text_description"
    return "—" unless mappable?

    "широта #{latitude.round(6)}, долгота #{longitude.round(6)}"
  end

  def pending_deletion_request?
    deletion_requests.pending.exists?
  end
end
