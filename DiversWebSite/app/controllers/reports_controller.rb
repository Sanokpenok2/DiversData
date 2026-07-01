# frozen_string_literal: true

class ReportsController < ApplicationController
  include ReportFilters

  before_action :require_login
  before_action :set_report, only: :show

  def index
    @filters = applied_report_filters
    @sort = report_sort_param
    scope = Report.submitted.filtered(@filters).sorted_by(@sort).includes(:photos)

    if ActiveModel::Type::Boolean.new.cast(@filters[:favorites_only])
      favorite_ids = current_scientist.favorites.pluck(:report_id)
      scope = scope.where(id: favorite_ids.presence || [0])
    end

    total_count = scope.count
    @pagination = ReportListPagination.new(
      page: params[:page],
      per_page: params[:per_page],
      total: total_count
    )
    @per_page = @pagination.per_page
    @reports = scope.offset(@pagination.offset).limit(@pagination.per_page)
  end

  def show
    @favorite = current_scientist.favorites.find_by(report_id: @report.id)
    @pending_deletion = @report.pending_deletion_request?
  end

  def lookup
    report_id = params[:id].to_s.gsub(/\D/, "")
    if report_id.blank?
      redirect_to root_path, alert: "Укажите номер отчёта."
      return
    end

    report = Report.submitted.find_by(id: report_id)
    unless report
      redirect_to root_path, alert: "Отчёт ##{report_id} не найден."
      return
    end

    if report.mappable?
      redirect_to root_path(report_id: report.id), notice: "Отчёт ##{report.id} показан на карте."
    else
      redirect_to report_path(report), notice: "Отчёт ##{report.id} без координат — открыта полная карточка."
    end
  end

  private

  def report_sort_param
    sort = params[:sort].to_s
    Report::SORT_OPTIONS.key?(sort) ? sort : Report::DEFAULT_SORT
  end

  def set_report
    @report = Report.submitted.find(params[:id])
  end
end
