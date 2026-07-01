# frozen_string_literal: true

module Admin
  class RegistrationTokensController < ApplicationController
    before_action :require_admin

    def index
      @tokens = RegistrationToken.recent.includes(:created_by, :used_by)
    end

    def create
      token = current_scientist.created_tokens.create!(expires_at: 30.days.from_now)
      redirect_to admin_registration_tokens_path, notice: "Создан токен: #{token.token}"
    end

    def destroy
      token = RegistrationToken.find(params[:id])
      if token.used_at?
        redirect_to admin_registration_tokens_path, alert: "Нельзя удалить уже использованный токен."
      else
        token.destroy!
        redirect_to admin_registration_tokens_path, notice: "Токен удалён."
      end
    end
  end
end
