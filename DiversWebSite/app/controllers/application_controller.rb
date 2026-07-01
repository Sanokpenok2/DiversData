# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_login

  helper_method :current_scientist, :logged_in?, :admin?

  private

  def current_scientist
    @current_scientist ||= Scientist.find_by(id: session[:scientist_id]) if session[:scientist_id]
  end

  def logged_in?
    current_scientist.present?
  end

  def admin?
    logged_in? && current_scientist.admin?
  end

  def require_login
    return if logged_in?

    redirect_to login_path, alert: "Войдите в аккаунт для доступа к этой странице."
  end

  def require_admin
    require_login
    return if admin?

    redirect_to root_path, alert: "Доступ только для администратора."
  end
end
