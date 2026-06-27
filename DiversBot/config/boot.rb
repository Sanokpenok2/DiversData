# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'sequel'
require 'json'
require 'date'
require 'time'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'divers_bot/database'
require 'divers_bot/models/user_session'
require 'divers_bot/models/report'
require 'divers_bot/models/report_photo'
require 'divers_bot/services/messages'
require 'divers_bot/services/spam_guard'
require 'divers_bot/services/conversation'
require 'divers_bot/bot'

DiversBot::Database.connect!
Sequel::Model.db = DiversBot::Database.DB
