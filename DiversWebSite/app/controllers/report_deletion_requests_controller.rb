# frozen_string_literal: true

class ReportDeletionRequestsController < ApplicationController
  before_action :require_login
  before_action :set_report

  def create
    request_record = @report.deletion_requests.build(
      requested_by: current_scientist,
      reason: deletion_params[:reason]
    )

    if request_record.save
      redirect_to report_path(@report), notice: "Запрос на удаление отправлен администратору."
    else
      redirect_to report_path(@report), alert: request_record.errors.full_messages.to_sentence
    end
  end

  private

  def set_report
    @report = Report.submitted.find(params[:report_id])
  end

  def deletion_params
    params.require(:report_deletion_request).permit(:reason)
  end
end
