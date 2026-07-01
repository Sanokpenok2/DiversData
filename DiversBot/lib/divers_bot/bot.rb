# frozen_string_literal: true

require 'max_bot_api'
require 'fileutils'

module DiversBot
  class Bot
    UPDATE_TYPES = %w[message_created bot_started message_callback].freeze
    PID_FILE = File.expand_path('../../tmp/divers_bot.pid', __dir__)

    def self.client
      @client ||= build_client
    end

    def self.build_client
      base_url = ENV.fetch('MAX_API_BASE_URL', MaxBotApi::Client::DEFAULT_BASE_URL)
      faraday = Faraday.new(url: base_url) do |f|
        f.request :multipart
        f.request :url_encoded
        f.adapter Faraday.default_adapter
        f.ssl.verify = ssl_verify? if f.respond_to?(:ssl)
      end

      MaxBotApi::Client.new(
        token: ENV.fetch('MAX_BOT_TOKEN'),
        base_url: base_url,
        faraday: faraday
      )
    end

    def self.ssl_verify?
      ENV.fetch('MAX_SSL_VERIFY', 'true') != 'false'
    end

    def self.acquire_pid_lock!
      if File.exist?(PID_FILE)
        old_pid = File.read(PID_FILE).to_s.strip.to_i
        if old_pid.positive? && process_alive?(old_pid)
          abort "Бот уже запущен (PID #{old_pid}). Остановите его перед новым запуском."
        end
      end

      FileUtils.mkdir_p(File.dirname(PID_FILE))
      File.write(PID_FILE, Process.pid.to_s)
      at_exit { File.delete(PID_FILE) if File.exist?(PID_FILE) && File.read(PID_FILE).to_i == Process.pid }
    end

    def self.process_alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    def self.verify_connection!
      info = client.bots.get_bot
      name = info[:username] || info[:name] || info[:user_id]
      puts "Подключено к MAX: #{name}"
    rescue MaxBotApi::Error => e
      abort "Ошибка MAX API: #{e.message}\nПроверьте MAX_BOT_TOKEN в .env"
    rescue StandardError => e
      abort "Не удалось подключиться к MAX API (#{e.class}: #{e.message})"
    end

    def self.run!
      acquire_pid_lock!
      verify_connection!

      puts "DiversBot (MAX) started at #{Time.now.utc} (PID #{Process.pid})"

      client.each_update(types: UPDATE_TYPES) do |update|
        process_update(update)
      rescue StandardError => e
        warn "[ERROR] update=#{update[:update_type]}: #{e.class}: #{e.message}"
        warn e.backtrace.first(5).join("\n")
        notify_error(update)
      end
    end

    def self.notify_error(update)
      chat_id = update.dig(:message, :recipient, :chat_id) || update[:chat_id]
      return unless chat_id

      message = MaxBotApi::Builders::MessageBuilder.new
                                                   .set_chat(chat_id)
                                                   .set_text('⚠️ Произошла ошибка при обработке сообщения. Попробуйте /start или /cancel.')
      client.messages.send(message)
    rescue StandardError
      nil
    end

    def self.process_update(update)
      case update[:update_type]
      when 'message_callback'
        handle_callback(update)
      when 'message_created', 'bot_started'
        incoming = Messenger::IncomingMessage.from_update(update)
        return unless incoming&.from&.id

        Services::Conversation.new(client, incoming).handle
      end
    end

    def self.handle_callback(update)
      callback_id = update.dig(:callback, :callback_id) || update[:callback_id]
      payload = update.dig(:callback, :payload) || update[:payload]
      chat_id = update.dig(:message, :recipient, :chat_id) || update[:chat_id]

      if callback_id
        client.messages.answer_on_callback(callback_id: callback_id, answer: { notification: '' })
      end

      return unless chat_id && payload

      synthetic_update = {
        update_type: 'message_created',
        message: update[:message] || {
          recipient: { chat_id: chat_id },
          sender: update.dig(:callback, :user) || update[:user] || {},
          body: { text: payload.to_s }
        }
      }
      synthetic_update[:message][:body][:text] = payload.to_s unless synthetic_update[:message][:body][:text]

      incoming = Messenger::IncomingMessage.new(synthetic_update)
      Services::Conversation.new(client, incoming).handle if incoming.from&.id
    end
  end
end
