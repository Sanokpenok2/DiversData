# frozen_string_literal: true

module Admin
  class ScientistsController < ApplicationController
    before_action :require_admin

    def index
      @scientists = Scientist.ordered
    end

    def destroy
      scientist = Scientist.find(params[:id])
      if scientist.id == current_scientist.id
        redirect_to admin_scientists_path, alert: "Нельзя удалить свой аккаунт."
        return
      end

      scientist.destroy!
      redirect_to admin_scientists_path, notice: "Аккаунт #{scientist.name} удалён."
    end
  end
end
