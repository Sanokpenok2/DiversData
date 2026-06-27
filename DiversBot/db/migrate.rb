# frozen_string_literal: true

require_relative '../config/boot'

Sequel.extension :migration
Sequel::Migrator.run(DiversBot::Database::DB, File.expand_path('migrations', __dir__))

puts 'Migrations completed successfully.'
