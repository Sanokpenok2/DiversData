# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'sequel'

Sequel.extension :migration

database_url = ENV.fetch('DATABASE_URL')
db = Sequel.connect(database_url)
db.extension :pg_json

Sequel::Migrator.run(db, File.expand_path('migrations', __dir__))

puts 'Migrations completed successfully.'
