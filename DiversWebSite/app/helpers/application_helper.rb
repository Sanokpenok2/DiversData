# frozen_string_literal: true

module ApplicationHelper
  def flash_class(key)
    case key.to_s
    when "notice" then "alert-success"
    when "alert" then "alert-danger"
    else "alert-info"
    end
  end

  def role_label(scientist)
    scientist.admin? ? "Администратор" : "Учёный"
  end
end
