# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :require_login
  def new
    redirect_to root_path if logged_in?
  end

  def create
    scientist = Scientist.find_by(email: params[:email].to_s.strip.downcase)
    if scientist&.authenticate(params[:password])
      session[:scientist_id] = scientist.id
      redirect_to root_path, notice: "Добро пожаловать, #{scientist.name}!"
    else
      flash.now[:alert] = "Неверный email или пароль."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Вы вышли из аккаунта."
  end
end
