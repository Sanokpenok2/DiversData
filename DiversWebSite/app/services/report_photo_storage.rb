# frozen_string_literal: true

module ReportPhotoStorage
  module_function

  def root
    @root ||= begin
      path = ENV.fetch("REPORT_PHOTOS_STORAGE") do
        Rails.root.join("../storage/report_photos").expand_path.to_s
      end
      FileUtils.mkdir_p(path)
      path
    end
  end

  def absolute_path(relative)
    return nil if relative.blank?

    File.expand_path(relative, root)
  end

  def stored_file?(photo)
    path = absolute_path(photo.storage_path)
    path.present? && File.file?(path)
  end

  def content_type(path)
    case File.extname(path).downcase
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".png" then "image/png"
    when ".gif" then "image/gif"
    when ".webp" then "image/webp"
    when ".heic" then "image/heic"
    else "application/octet-stream"
    end
  end
end
