# frozen_string_literal: true

require 'telegram/bot'

module DiversBot
  class Bot
    def self.run!
      token = ENV.fetch('TELEGRAM_BOT_TOKEN')

      Telegram::Bot::Client.run(token) do |bot|
        puts "DiversBot started at #{Time.now.utc}"

        bot.listen do |message|
          next unless message.is_a?(Telegram::Bot::Types::Message)
          next if message.from.nil?

          begin
            Services::Conversation.new(bot, message).handle
          rescue StandardError => e
            warn "[ERROR] user=#{message.from.id}: #{e.class}: #{e.message}"
            warn e.backtrace.first(5).join("\n")
            bot.api.send_message(
              chat_id: message.chat.id,
              text: '⚠️ Произошла ошибка при обработке сообщения. Попробуйте /start или /cancel.'
            )
          end
        end
      end
    end
  end
end
