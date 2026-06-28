# frozen_string_literal: true

require 'telegram/bot'

module DiversBot
  class Bot
    def self.configure_telegram!
      proxy = ENV['TELEGRAM_PROXY']
      return if proxy.nil? || proxy.strip.empty?

      Telegram::Bot.configure do |config|
        if proxy.start_with?('socks')
          config.adapter = :excon
          config.adapter_options = { socks5_proxy: proxy }
        else
          config.adapter_options = { proxy: proxy }
        end
      end
    end

    def self.verify_connection!(token)
      configure_telegram!
      client = Telegram::Bot::Client.new(token)
      me = client.api.get_me
      puts "Подключено к Telegram: @#{me.username}"
    rescue Telegram::Bot::Exceptions::ResponseError => e
      abort "Ошибка Telegram API: #{e.message}\nПроверьте TELEGRAM_BOT_TOKEN в .env"
    rescue StandardError => e
      abort <<~MSG
        Не удалось подключиться к api.telegram.org (#{e.class}: #{e.message})

        Telegram API недоступен из вашей сети. Варианты решения:
          1. Включите VPN и перезапустите бота
          2. Укажите прокси в .env: TELEGRAM_PROXY=socks5://127.0.0.1:1080
             (адрес вашего локального VPN/прокси)
      MSG
    end

    def self.run!
      token = ENV.fetch('TELEGRAM_BOT_TOKEN')
      verify_connection!(token)

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
