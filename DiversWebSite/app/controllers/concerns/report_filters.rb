# frozen_string_literal: true

module ReportFilters
  extend ActiveSupport::Concern

  FILTER_KEYS = %i[
    date_from date_to encounter_type substrate_type
    depth_min depth_max depth_exact favorites_only report_id
  ].freeze

  def default_report_filters
    {
      date_from: "",
      date_to: "",
      encounter_type: "",
      substrate_type: "",
      depth_min: "",
      depth_max: "",
      depth_exact: "",
      favorites_only: "0",
      report_id: ""
    }
  end

  def report_filter_params
    params.permit(*FILTER_KEYS)
  end

  def applied_report_filters(overrides = {})
    default_report_filters.merge(report_filter_params.to_h.symbolize_keys).merge(overrides)
  end
end
