# frozen_string_literal: true

class ReportsController < ApplicationController
  before_action :require_login
  before_action :set_report, only: :show

  def show
    @favorite = current_scientist.favorites.find_by(report_id: @report.id)
    @pending_deletion = @report.pending_deletion_request?
  end

  def descriptions
    @reports = Report.text_description.includes(:photos).recent_first.limit(500)
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

  def set_report
    @report = Report.submitted.find(params[:id])
  end
end
