# frozen_string_literal: true

class ReportDeletionRequest < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :report
  belongs_to :requested_by, class_name: "Scientist"
  belongs_to :reviewed_by, class_name: "Scientist", optional: true

  validates :reason, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :status, inclusion: { in: STATUSES }
  validate :report_must_be_submitted, on: :create
  validate :no_pending_duplicate, on: :create

  scope :pending, -> { where(status: "pending") }
  scope :recent_first, -> { order(created_at: :desc) }

  def pending?
    status == "pending"
  end

  def approve!(admin:, note: nil)
    transaction do
      update!(
        status: "approved",
        reviewed_by: admin,
        reviewed_at: Time.current,
        admin_note: note
      )
      report.update!(status: "deleted", updated_at: Time.current)
    end
  end

  def reject!(admin:, note: nil)
    update!(
      status: "rejected",
      reviewed_by: admin,
      reviewed_at: Time.current,
      admin_note: note
    )
  end

  def status_label
    {
      "pending" => "Ожидает",
      "approved" => "Одобрено",
      "rejected" => "Отклонено"
    }.fetch(status, status)
  end

  private

  def report_must_be_submitted
    return if report&.status == "submitted"

    errors.add(:report, "уже удалён или недоступен")
  end

  def no_pending_duplicate
    return unless report_id

    if ReportDeletionRequest.pending.exists?(report_id: report_id)
      errors.add(:report, "уже есть активный запрос на удаление")
    end
  end
end
