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

  SUBSTRATE_TYPES = [
    "Скала (цельная твёрдая поверхность – не рассыпается, нет стыков)",
    "Валуны (крупные камни > 30 см в диаметре, видны границы между ними)",
    "Галька",
    "Песок",
    "Искусственная конструкция (бетон, затонувшее судно и т.д.)"
  ].freeze

  SORT_OPTIONS = {
    "date_desc" => "Дата наблюдения (сначала новые)",
    "date_asc" => "Дата наблюдения (сначала старые)",
    "id_desc" => "Номер отчёта (сначала новые)",
    "id_asc" => "Номер отчёта (сначала старые)",
    "depth_desc" => "Глубина (сначала глубже)",
    "depth_asc" => "Глубина (сначала мельче)",
    "created_desc" => "Дата добавления (сначала новые)",
    "created_asc" => "Дата добавления (сначала старые)"
  }.freeze

  DEFAULT_SORT = "date_desc"

  scope :with_coordinates, -> { where.not(latitude: nil, longitude: nil) }
  scope :without_coordinates, -> { where(latitude: nil).or(where(longitude: nil)) }
  scope :submitted, -> { where(status: "submitted") }
  scope :recent_first, -> { sorted_by(DEFAULT_SORT) }

  def self.sorted_by(sort)
    case sort.to_s
    when "date_asc"
      order(observation_date: :asc, id: :asc)
    when "id_desc"
      order(id: :desc)
    when "id_asc"
      order(id: :asc)
    when "depth_desc"
      order(depth_m: :desc, id: :desc)
    when "depth_asc"
      order(depth_m: :asc, id: :desc)
    when "created_desc"
      order(created_at: :desc, id: :desc)
    when "created_asc"
      order(created_at: :asc, id: :asc)
    else
      order(observation_date: :desc, id: :desc)
    end
  end

  scope :filtered, lambda { |params|
    scope = all
    scope = scope.where("observation_date >= ?", params[:date_from]) if params[:date_from].present?
    scope = scope.where("observation_date <= ?", params[:date_to]) if params[:date_to].present?
    scope = scope.where(encounter_type: params[:encounter_type]) if params[:encounter_type].present?
    scope = scope.where(substrate_type: params[:substrate_type]) if params[:substrate_type].present?
    scope = scope.where("depth_m >= ?", params[:depth_min]) if params[:depth_min].present?
    scope = scope.where("depth_m <= ?", params[:depth_max]) if params[:depth_max].present?
    if ActiveModel::Type::Boolean.new.cast(params[:depth_exact])
      scope = scope.where(depth_is_approximate: false)
    end
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
    parts = []
    parts << location_description if location_description.present?
    if mappable?
      parts << "широта #{latitude.round(6)}, долгота #{longitude.round(6)}"
    end
    return parts.join(" · ") if parts.any?

    "—"
  end

  def pending_deletion_request?
    deletion_requests.pending.exists?
  end

  def substrate_short_label
    substrate_type.to_s.sub(/\s*\(.*/, "")
  end
end
