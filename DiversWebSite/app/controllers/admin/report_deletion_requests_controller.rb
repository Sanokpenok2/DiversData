# frozen_string_literal: true

module Admin
  class ReportDeletionRequestsController < ApplicationController
    before_action :require_admin
    before_action :set_request, only: %i[approve reject]

    def index
      @pending_requests = ReportDeletionRequest.pending.recent_first.includes(:report, :requested_by)
      @processed_requests = ReportDeletionRequest.where.not(status: "pending").recent_first
                                                 .includes(:report, :requested_by, :reviewed_by)
                                                 .limit(50)
    end

    def approve
      @request.approve!(admin: current_scientist, note: review_params[:admin_note])
      redirect_to admin_report_deletion_requests_path, notice: "Отчёт ##{@request.report_id} удалён."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_report_deletion_requests_path, alert: e.record.errors.full_messages.to_sentence
    end

    def reject
      @request.reject!(admin: current_scientist, note: review_params[:admin_note])
      redirect_to admin_report_deletion_requests_path, notice: "Запрос на удаление отчёта ##{@request.report_id} отклонён."
    end

    private

    def set_request
      @request = ReportDeletionRequest.pending.find(params[:id])
    end

    def review_params
      params.fetch(:report_deletion_request, {}).permit(:admin_note)
    end
  end
end
