# frozen_string_literal: true

class Scientist < ApplicationRecord
  has_secure_password

  ROLES = %w[scientist admin].freeze

  has_many :created_tokens, class_name: "RegistrationToken", foreign_key: :created_by_id, dependent: :destroy,
                            inverse_of: :created_by
  has_many :favorites, dependent: :destroy
  has_many :favorite_reports, through: :favorites, source: :report
  has_many :deletion_requests, class_name: "ReportDeletionRequest", foreign_key: :requested_by_id, dependent: :destroy,
                               inverse_of: :requested_by
  has_many :reviewed_deletion_requests, class_name: "ReportDeletionRequest", foreign_key: :reviewed_by_id,
                                        dependent: :nullify, inverse_of: :reviewed_by

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }

  before_validation :normalize_email

  scope :ordered, -> { order(:name) }

  def admin?
    role == "admin"
  end

  def favorited?(report)
    favorites.exists?(report_id: report.id)
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
