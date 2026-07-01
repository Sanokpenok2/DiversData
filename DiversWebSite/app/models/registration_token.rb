# frozen_string_literal: true

class RegistrationToken < ApplicationRecord
  belongs_to :created_by, class_name: "Scientist"
  belongs_to :used_by, class_name: "Scientist", optional: true

  validates :token, presence: true, uniqueness: true

  scope :available, lambda {
    where(used_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current)
  }
  scope :recent, -> { order(created_at: :desc) }

  before_validation :generate_token, on: :create

  def available?
    used_at.nil? && (expires_at.nil? || expires_at > Time.current)
  end

  def mark_used!(scientist)
    update!(used_by: scientist, used_at: Time.current)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end
end
