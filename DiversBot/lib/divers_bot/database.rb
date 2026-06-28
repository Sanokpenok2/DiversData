# frozen_string_literal: true

module DiversBot
  module Database
    class << self
      attr_reader :DB

      def connect!
        database_url = ENV.fetch('DATABASE_URL')
        @DB = Sequel.connect(database_url)
        @DB.extension :pg_json
      end
    end
  end
end
