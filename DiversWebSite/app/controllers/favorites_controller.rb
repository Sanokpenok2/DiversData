# frozen_string_literal: true

class FavoritesController < ApplicationController
  before_action :require_login
  before_action :set_report, only: %i[create destroy]

  def index
    @favorites = current_scientist.favorites.includes(report: :photos).order(created_at: :desc)
    @reports = @favorites.map(&:report)
  end

  def create
    favorite = current_scientist.favorites.find_or_create_by!(report: @report)
    respond_to do |format|
      format.html { redirect_back fallback_location: report_path(@report), notice: "Отчёт добавлен в избранное." }
      format.json { render json: { favorited: true, id: favorite.id } }
    end
  end

  def destroy
    favorite = current_scientist.favorites.find_by!(report: @report)
    favorite.destroy!
    respond_to do |format|
      format.html { redirect_back fallback_location: favorites_path, notice: "Отчёт удалён из избранного." }
      format.json { render json: { favorited: false } }
    end
  end

  private

  def set_report
    @report = Report.submitted.find(params[:report_id])
  end
end
