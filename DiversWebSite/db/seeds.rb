# frozen_string_literal: true

email = ENV.fetch("ADMIN_EMAIL", "admin@diversdata.local")
password = ENV.fetch("ADMIN_PASSWORD", "admin12345")
name = ENV.fetch("ADMIN_NAME", "Администратор")

admin = Scientist.find_or_initialize_by(email: email)
admin.assign_attributes(name: name, role: "admin", password: password, password_confirmation: password)

if admin.save
  puts "Admin ready: #{admin.email} (#{admin.role})"
else
  warn "Admin seed failed: #{admin.errors.full_messages.join(', ')}"
end
