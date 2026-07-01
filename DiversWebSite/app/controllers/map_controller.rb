# frozen_string_literal: true

class MapController < ApplicationController
  def index
    @filters = default_filters
    @filters[:report_id] = params[:report_id].to_s if params[:report_id].present?
  end

  def reports
    scope = Report.submitted.with_coordinates.filtered(filter_params)
    favorite_ids = current_scientist_favorite_ids

    if ActiveModel::Type::Boolean.new.cast(params[:favorites_only])
      scope = scope.where(id: favorite_ids.presence || [0])
    end

    reports = scope.includes(:photos).limit(5000)

    render json: reports.map { |report| report_json(report, favorite_ids) }
  end

  private

  def default_filters
    {
      date_from: "",
      date_to: "",
      encounter_type: "",
      location_type: "",
      depth_min: "",
      depth_max: "",
      favorites_only: "0",
      report_id: ""
    }
  end

  def filter_params
    params.permit(:date_from, :date_to, :encounter_type, :location_type, :depth_min, :depth_max,
                  :favorites_only, :report_id)
  end

  def current_scientist_favorite_ids
    return [] unless logged_in?

    current_scientist.favorites.pluck(:report_id)
  end

  def report_json(report, favorite_ids)
    {
      id: report.id,
      latitude: report.latitude,
      longitude: report.longitude,
      observation_date: report.observation_date&.strftime("%d.%m.%Y"),
      encounter_type: report.encounter_label,
      depth_m: report.depth_m,
      depth_label: report.depth_label,
      location_type: report.location_label,
      substrate_type: report.substrate_type,
      reporter_name: report.reporter_name,
      photos_count: report.photos.size,
      favorited: favorite_ids.include?(report.id),
      show_url: report_path(report)
    }
  end
end
