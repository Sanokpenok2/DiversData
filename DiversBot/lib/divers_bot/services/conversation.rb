# frozen_string_literal: true

require 'telegram/bot/types'

module DiversBot
  module Services
    class Conversation
      CANCEL_COMMANDS = %w[/cancel отмена].freeze
      SKIP_COMMANDS = %w[/skip пропустить].freeze
      DONE_COMMANDS = %w[/done готово].freeze
      FINISH_COMMANDS = %w[/finish завершить].freeze

      def initialize(bot, message)
        @bot = bot
        @message = message
        @user = message.from
        @chat_id = message.chat.id
        @text = message.text&.strip
        @session = Models::UserSession.find_or_create_for(@user)
        @spam_guard = SpamGuard.new(@user.id)
      end

      def handle
        return handle_command if command_message?

        unless @spam_guard.allow_message?
          reply(Messages.spam_blocked)
          return
        end

        dispatch_state
      end

      private

      def command_message?
        @text&.start_with?('/')
      end

      def handle_command
        case @text.split.first.downcase
        when '/start'
          handle_start
        when '/cancel'
          handle_cancel
        when '/help'
          handle_start
        else
          dispatch_state if @session.state != 'idle'
        end
      end

      def handle_start
        unless @spam_guard.allow_message?
          reply(Messages.spam_blocked)
          return
        end

        @session.reset!
        reply(Messages.welcome, reply_markup: start_keyboard)
      end

      def handle_cancel
        @session.reset!
        reply(Messages.cancelled, reply_markup: remove_keyboard)
      end

      def dispatch_state
        if cancel_requested?
          handle_cancel
          return
        end

        case @session.state
        when 'idle' then handle_idle
        when 'waiting_date' then handle_date
        when 'waiting_location_choice' then handle_location_choice
        when 'waiting_map_location' then handle_map_location
        when 'waiting_coordinates' then handle_coordinates
        when 'waiting_text_location' then handle_text_location
        when 'waiting_encounter_type' then handle_encounter_type
        when 'waiting_encounter_radius' then handle_encounter_radius
        when 'waiting_depth' then handle_depth
        when 'waiting_depth_precision' then handle_depth_precision
        when 'waiting_density_photos' then handle_density_photos
        when 'waiting_substrate_type' then handle_substrate_type
        when 'waiting_substrate_photo' then handle_substrate_photo
        when 'waiting_additional_info' then handle_additional_info
        when 'waiting_extra_photos' then handle_extra_photos
        else
          @session.reset!
          reply(Messages.welcome, reply_markup: start_keyboard)
        end
      end

      # --- idle ---

      def handle_idle
        if start_report_requested?
          unless @spam_guard.allow_new_report?
            reply(Messages.daily_limit_reached)
            return
          end

          @session.transition_to!('waiting_date', 'photos' => [])
          reply(Messages.ask_date, reply_markup: cancel_keyboard)
        else
          reply('Нажмите «Начать отчёт» или /start для инструкции.', reply_markup: start_keyboard)
        end
      end

      # --- date ---

      def handle_date
        date = parse_date(@text)
        unless date
          reply(Messages.invalid_date)
          return
        end

        if date > Date.today
          reply('❌ Дата не может быть в будущем.')
          return
        end

        @session.transition_to!('waiting_location_choice', 'observation_date' => date.iso8601)
        reply(Messages.ask_location_choice, reply_markup: location_choice_keyboard)
      end

      # --- location ---

      def handle_location_choice
        case @text
        when '🗺 На карте', 'На карте'
          @session.transition_to!('waiting_map_location')
          reply(Messages.ask_map_location, reply_markup: map_location_keyboard)
        when '🌐 Координаты', 'Координаты'
          @session.transition_to!('waiting_coordinates')
          reply(Messages.ask_coordinates, reply_markup: cancel_keyboard)
        when '📝 Описание', 'Описание'
          @session.transition_to!('waiting_text_location')
          reply(Messages.ask_text_location, reply_markup: cancel_keyboard)
        else
          reply('Выберите способ указания места с помощью кнопок.', reply_markup: location_choice_keyboard)
        end
      end

      def handle_map_location
        if @message.web_app_data
          data = JSON.parse(@message.web_app_data.data)
          save_location('map_point', data['lat'], data['lng'])
          return
        end

        if @message.location
          loc = @message.location
          save_location('map_point', loc.latitude, loc.longitude)
          return
        end

        reply('Отправьте геопозицию или выберите точку на карте.', reply_markup: map_location_keyboard)
      end

      def handle_coordinates
        coords = parse_coordinates(@text)
        unless coords
          reply(Messages.invalid_coordinates)
          return
        end

        lat, lon = coords
        unless valid_coordinates?(lat, lon)
          reply(Messages.invalid_coordinates)
          return
        end

        @bot.api.send_location(chat_id: @chat_id, latitude: lat, longitude: lon)
        save_location('coordinates', lat, lon)
        reply(Messages.coordinates_confirmed(lat, lon))
      end

      def handle_text_location
        return reply('Опишите место обнаружения текстом.') if @text.nil? || @text.empty?

        @session.transition_to!(
          'waiting_encounter_type',
          'location_type' => 'text_description',
          'location_description' => @text
        )
        reply(Messages.ask_encounter_type, reply_markup: encounter_type_keyboard)
      end

      def save_location(type, lat, lon)
        @session.transition_to!(
          'waiting_encounter_type',
          'location_type' => type,
          'latitude' => lat,
          'longitude' => lon
        )
        reply(Messages.location_confirmed)
        reply(Messages.ask_encounter_type, reply_markup: encounter_type_keyboard)
      end

      # --- encounter ---

      def handle_encounter_type
        case @text
        when '🔹 Единичная встреча', 'Единичная встреча'
          @session.transition_to!('waiting_depth', 'encounter_type' => 'single')
          reply(Messages.ask_depth, reply_markup: cancel_keyboard)
        when '🔸 Множественная встреча', 'Множественная встреча'
          @session.transition_to!('waiting_encounter_radius', 'encounter_type' => 'multiple_in_radius')
          reply(Messages.ask_encounter_radius, reply_markup: cancel_keyboard)
        else
          reply('Выберите тип встречи с помощью кнопок.', reply_markup: encounter_type_keyboard)
        end
      end

      def handle_encounter_radius
        radius = parse_positive_float(@text)
        unless radius
          reply(Messages.invalid_radius)
          return
        end

        @session.transition_to!('waiting_depth', 'encounter_radius_m' => radius)
        reply(Messages.ask_depth, reply_markup: cancel_keyboard)
      end

      # --- depth ---

      def handle_depth
        depth = parse_positive_float(@text)
        unless depth
          reply(Messages.invalid_depth)
          return
        end

        @session.transition_to!('waiting_depth_precision', 'depth_m' => depth)
        reply(Messages.ask_depth_precision, reply_markup: depth_precision_keyboard)
      end

      def handle_depth_precision
        approximate = case @text
                      when '📐 Приблизительная', 'Приблизительная' then true
                      when '🎯 Точная', 'Точная' then false
                      else nil
                      end

        unless approximate.nil?
          @session.transition_to!('waiting_density_photos', 'depth_is_approximate' => approximate)
          reply(Messages.ask_density_photos, reply_markup: done_keyboard)
          return
        end

        reply('Выберите точность глубины с помощью кнопок.', reply_markup: depth_precision_keyboard)
      end

      # --- photos: density ---

      def handle_density_photos
        if done_requested?
          photos = density_photos
          if photos.empty?
            reply(Messages.need_density_photo)
            return
          end

          @session.transition_to!('waiting_substrate_type')
          reply(Messages.ask_substrate_type, reply_markup: cancel_keyboard)
          return
        end

        if photo_message?
          add_photo('density')
          reply(Messages.photo_added(density_photos.size), reply_markup: done_keyboard)
        else
          reply(Messages.need_photo, reply_markup: done_keyboard)
        end
      end

      # --- substrate ---

      def handle_substrate_type
        return reply('Опишите тип субстрата.') if @text.nil? || @text.empty?

        @session.transition_to!('waiting_substrate_photo', 'substrate_type' => @text)
        reply(Messages.ask_substrate_photo, reply_markup: skip_keyboard)
      end

      def handle_substrate_photo
        if skip_requested?
          @session.transition_to!('waiting_additional_info')
          reply(Messages.ask_additional_info, reply_markup: skip_keyboard)
          return
        end

        if photo_message?
          add_photo('substrate')
          @session.transition_to!('waiting_additional_info')
          reply(Messages.ask_additional_info, reply_markup: skip_keyboard)
        else
          reply(Messages.need_photo, reply_markup: skip_keyboard)
        end
      end

      # --- additional info ---

      def handle_additional_info
        unless skip_requested?
          @session.transition_to!('waiting_extra_photos', 'additional_info' => @text) if @text && !@text.empty?
        end

        if @session.state == 'waiting_additional_info'
          @session.transition_to!('waiting_extra_photos', 'additional_info' => nil)
        end

        reply(Messages.ask_extra_photos, reply_markup: finish_keyboard)
      end

      # --- extra photos & submit ---

      def handle_extra_photos
        if finish_requested?
          submit_report!
          return
        end

        if photo_message?
          caption = @message.caption
          add_photo('additional', caption)
          reply(Messages.extra_photo_added(additional_photos.size), reply_markup: finish_keyboard)
        else
          reply('Отправьте фото или нажмите «Завершить отчёт».', reply_markup: finish_keyboard)
        end
      end

      def submit_report!
        draft = @session.draft_data
        report = Models::Report.create_from_draft!(@user, draft)
        @session.reset!
        reply(Messages.report_saved(report.id), reply_markup: start_keyboard)
      end

      # --- helpers ---

      def start_report_requested?
        @text == '📝 Начать отчёт' || @text == 'Начать отчёт'
      end

      def done_requested?
        DONE_COMMANDS.include?(@text&.downcase) || @text == '✅ Готово'
      end

      def skip_requested?
        SKIP_COMMANDS.include?(@text&.downcase) || @text == '⏭ Пропустить'
      end

      def finish_requested?
        FINISH_COMMANDS.include?(@text&.downcase) || @text == '🏁 Завершить отчёт'
      end

      def cancel_requested?
        CANCEL_COMMANDS.include?(@text&.downcase) || @text&.start_with?('❌ Отмена')
      end

      def photo_message?
        @message.photo&.any?
      end

      def largest_photo
        @message.photo.max_by(&:file_size)
      end

      def add_photo(type, caption = nil)
        photos = @session.draft_data['photos'] || []
        photos << {
          'file_id' => largest_photo.file_id,
          'photo_type' => type,
          'caption' => caption
        }
        @session.transition_to!(@session.state, 'photos' => photos)
      end

      def density_photos
        Array(@session.draft_data['photos']).select { |p| p['photo_type'] == 'density' }
      end

      def additional_photos
        Array(@session.draft_data['photos']).select { |p| p['photo_type'] == 'additional' }
      end

      def parse_date(text)
        return nil unless text

        if text.match?(%r{\A(\d{1,2})\.(\d{1,2})\.(\d{4})\z})
          day, month, year = text.split('.').map(&:to_i)
          Date.new(year, month, day)
        elsif text.match?(/\A(\d{4})-(\d{2})-(\d{2})\z/)
          Date.parse(text)
        end
      rescue ArgumentError
        nil
      end

      def parse_coordinates(text)
        return nil unless text

        cleaned = text.tr(';', ',').gsub(/\s+/, ' ').strip
        parts = cleaned.include?(',') ? cleaned.split(',') : cleaned.split(' ')
        return nil unless parts.size >= 2

        [parts[0].to_f, parts[1].to_f]
      end

      def valid_coordinates?(lat, lon)
        lat.between?(-90, 90) && lon.between?(-180, 180) && !(lat.zero? && lon.zero?)
      end

      def parse_positive_float(text)
        return nil unless text

        value = text.tr(',', '.').to_f
        value.positive? ? value : nil
      rescue StandardError
        nil
      end

      def reply(text, **options)
        @bot.api.send_message(
          chat_id: @chat_id,
          text: text,
          parse_mode: 'Markdown',
          **options
        )
      end

      # --- keyboards ---

      def start_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [[Telegram::Bot::Types::KeyboardButton.new(text: '📝 Начать отчёт')]],
          resize_keyboard: true,
          one_time_keyboard: false
        )
      end

      def cancel_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [[Telegram::Bot::Types::KeyboardButton.new(text: '❌ Отмена (/cancel)')]],
          resize_keyboard: true
        )
      end

      def remove_keyboard
        Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
      end

      def location_choice_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [
            [Telegram::Bot::Types::KeyboardButton.new(text: '🗺 На карте')],
            [Telegram::Bot::Types::KeyboardButton.new(text: '🌐 Координаты')],
            [Telegram::Bot::Types::KeyboardButton.new(text: '📝 Описание')]
          ],
          resize_keyboard: true
        )
      end

      def map_location_keyboard
        buttons = []

        if ENV['WEB_APP_URL'] && !ENV['WEB_APP_URL'].empty?
          buttons << Telegram::Bot::Types::KeyboardButton.new(
            text: '🗺 Выбрать на карте',
            web_app: Telegram::Bot::Types::WebAppInfo.new(url: ENV['WEB_APP_URL'])
          )
        end

        buttons << Telegram::Bot::Types::KeyboardButton.new(
          text: '📍 Отправить геопозицию',
          request_location: true
        )

        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [buttons, [Telegram::Bot::Types::KeyboardButton.new(text: '❌ Отмена (/cancel)')]],
          resize_keyboard: true
        )
      end

      def encounter_type_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [
            [Telegram::Bot::Types::KeyboardButton.new(text: '🔹 Единичная встреча')],
            [Telegram::Bot::Types::KeyboardButton.new(text: '🔸 Множественная встреча')]
          ],
          resize_keyboard: true
        )
      end

      def depth_precision_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [
            [Telegram::Bot::Types::KeyboardButton.new(text: '📐 Приблизительная')],
            [Telegram::Bot::Types::KeyboardButton.new(text: '🎯 Точная')]
          ],
          resize_keyboard: true
        )
      end

      def done_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [[Telegram::Bot::Types::KeyboardButton.new(text: '✅ Готово')]],
          resize_keyboard: true
        )
      end

      def skip_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [[Telegram::Bot::Types::KeyboardButton.new(text: '⏭ Пропустить')]],
          resize_keyboard: true
        )
      end

      def finish_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [[Telegram::Bot::Types::KeyboardButton.new(text: '🏁 Завершить отчёт')]],
          resize_keyboard: true
        )
      end
    end
  end
end
