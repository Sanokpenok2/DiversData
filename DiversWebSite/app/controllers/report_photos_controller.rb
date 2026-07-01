# frozen_string_literal: true

class ReportPhotosController < ApplicationController
  before_action :require_login

  def show
    photo = ReportPhoto.find(params[:id])

    if ReportPhotoStorage.stored_file?(photo)
      path = ReportPhotoStorage.absolute_path(photo.storage_path)
      send_file path,
                disposition: "inline",
                type: ReportPhotoStorage.content_type(path),
                filename: File.basename(path)
      return
    end

    if photo.source_url.present?
      redirect_to photo.source_url, allow_other_host: true
      return
    end

    head :not_found
  end
end
