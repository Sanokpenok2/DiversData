# frozen_string_literal: true

module DiversBot
  module Services
    class SpamGuard
      def initialize(user_id)
        @user_id = user_id
        @max_messages_per_minute = ENV.fetch('SPAM_MAX_MESSAGES_PER_MINUTE', 20).to_i
        @max_reports_per_day = ENV.fetch('SPAM_MAX_REPORTS_PER_DAY', 10).to_i
        @cooldown_seconds = ENV.fetch('SPAM_COOLDOWN_SECONDS', 1).to_f
        @message_timestamps = []
        @last_message_at = nil
      end

      def allow_message?
        cleanup_old_timestamps!
        return false if rate_limit_exceeded?
        return false unless cooldown_passed?

        register_message!
        true
      end

      def allow_new_report?
        today_start = Time.now.utc.beginning_of_day
        count = Models::Report.where(max_user_id: @user_id)
                              .where { created_at >= today_start }
                              .count
        count < @max_reports_per_day
      end

      private

      def rate_limit_exceeded?
        @message_timestamps.size >= @max_messages_per_minute
      end

      def cooldown_passed?
        return true unless @last_message_at

        Time.now - @last_message_at >= @cooldown_seconds
      end

      def register_message!
        @message_timestamps << Time.now
        @last_message_at = Time.now
      end

      def cleanup_old_timestamps!
        cutoff = Time.now - 60
        @message_timestamps.select! { |timestamp| timestamp >= cutoff }
      end
    end
  end
end
