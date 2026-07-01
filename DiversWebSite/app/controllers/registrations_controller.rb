# frozen_string_literal: true

class RegistrationsController < ApplicationController
  skip_before_action :require_login
  def new
    redirect_to root_path if logged_in?
  end

  def create
    token_record = RegistrationToken.available.find_by(token: params[:registration_token].to_s.strip)
    unless token_record
      flash.now[:alert] = "Недействительный или уже использованный токен регистрации."
      return render :new, status: :unprocessable_entity
    end

    scientist = Scientist.new(registration_params.merge(role: "scientist"))
    if scientist.save
      token_record.mark_used!(scientist)
      session[:scientist_id] = scientist.id
      redirect_to root_path, notice: "Регистрация успешна. Добро пожаловать!"
    else
      flash.now[:alert] = scientist.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.permit(:name, :email, :password, :password_confirmation)
  end
end
