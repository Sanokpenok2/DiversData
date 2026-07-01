# frozen_string_literal: true

module ReportsHelper
  PHOTO_PLACEHOLDER = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='400' height='300' viewBox='0 0 400 300'%3E%3Crect fill='%23eef3f8' width='400' height='300'/%3E%3Ctext x='50%25' y='50%25' dominant-baseline='middle' text-anchor='middle' fill='%23666' font-family='sans-serif' font-size='16'%3EФото недоступно%3C/text%3E%3C/svg%3E".freeze

  def report_photo_src(photo)
    report_photo_path(photo)
  rescue StandardError
    PHOTO_PLACEHOLDER
  end
end
