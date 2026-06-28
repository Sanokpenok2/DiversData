# frozen_string_literal: true

require 'telegram/bot'

module DiversBot
  module Services
    class Conversation
      CANCEL_COMMANDS = %w[/cancel отмена].freeze
      SKIP_COMMANDS = %w[/skip пропустить].freeze
      DONE_COMMANDS = %w[/done готово].freeze
      FINISH_COMMANDS = %w[/finish завершить].freeze
      BACK_COMMANDS = %w[/back назад].freeze
      BACK_TEXT = '⬅️ Назад'
      CHANGE_LOCATION_TEXT = '📍 Изменить место'

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
        @session.track_message_id!(@message.message_id)
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
        when '/back'
          handle_back
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

        message_ids = Array(@session.draft_data['chat_message_ids'])
        message_ids << @message.message_id if @message.message_id

        @session.reset!
        delete_chat_messages(message_ids.uniq)
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

        if back_requested?
          handle_back
          return
        end

        if change_location_requested?
          go_to_location_choice!(clear_downstream: true)
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

      def handle_back
        case @session.state
        when 'waiting_date'
          @session.reset!
          reply(Messages.welcome, reply_markup: start_keyboard)
        when 'waiting_location_choice'
          @session.transition_to!('waiting_date')
          reply(Messages.ask_date, reply_markup: date_keyboard)
        when 'waiting_map_location', 'waiting_coordinates', 'waiting_text_location'
          go_to_location_choice!
        when 'waiting_encounter_type'
          go_to_location_choice!
        when 'waiting_encounter_radius'
          @session.transition_to!('waiting_encounter_type', 'encounter_radius_m' => nil)
          reply(Messages.ask_encounter_type, reply_markup: encounter_type_keyboard)
        when 'waiting_depth'
          if draft['encounter_type'] == 'multiple_in_radius'
            @session.transition_to!('waiting_encounter_radius', 'depth_m' => nil)
            reply(Messages.ask_encounter_radius, reply_markup: standard_keyboard)
          else
            @session.transition_to!('waiting_encounter_type', 'depth_m' => nil)
            reply(Messages.ask_encounter_type, reply_markup: encounter_type_keyboard)
          end
        when 'waiting_depth_precision'
          @session.transition_to!('waiting_depth', 'depth_is_approximate' => nil)
          reply(Messages.ask_depth, reply_markup: standard_keyboard)
        when 'waiting_density_photos'
          @session.transition_to!('waiting_depth_precision')
          reply(Messages.ask_depth_precision, reply_markup: depth_precision_keyboard)
        when 'waiting_substrate_type'
          @session.transition_to!('waiting_density_photos')
          reply(Messages.ask_density_photos, reply_markup: done_keyboard)
        when 'waiting_substrate_photo'
          @session.transition_to!('waiting_substrate_type', 'substrate_type' => nil)
          reply(Messages.ask_substrate_type, reply_markup: standard_keyboard)
        when 'waiting_additional_info'
          @session.transition_to!('waiting_substrate_photo')
          reply(Messages.ask_substrate_photo, reply_markup: skip_keyboard)
        when 'waiting_extra_photos'
          @session.transition_to!('waiting_additional_info')
          reply(Messages.ask_additional_info, reply_markup: skip_keyboard)
        else
          reply('Нечего возвращать. Нажмите /start.')
        end
      end

      def go_to_location_choice!(clear_downstream: false)
        updates = {
          'location_type' => nil,
          'latitude' => nil,
          'longitude' => nil,
          'location_description' => nil
        }

        if clear_downstream
          updates.merge!(
            'encounter_type' => nil,
            'encounter_radius_m' => nil,
            'depth_m' => nil,
            'depth_is_approximate' => nil,
            'substrate_type' => nil,
            'additional_info' => nil,
            'photos' => []
          )
        end

        @session.transition_to!('waiting_location_choice', updates)
        reply(Messages.ask_location_choice, reply_markup: location_choice_keyboard)
      end

      # --- idle ---

      def handle_idle
        if start_report_requested?
          unless @spam_guard.allow_new_report?
            reply(Messages.daily_limit_reached)
            return
          end

          @session.transition_to!('waiting_date', 'photos' => [])
          reply(Messages.ask_date, reply_markup: date_keyboard)
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
        when '📍 Геопозиция', 'Геопозиция'
          @session.transition_to!('waiting_map_location')
          reply(Messages.ask_geolocation, reply_markup: geolocation_keyboard)
        when '🗺 Карта', '🗺 На карте', 'Карта', 'На карте'
          @session.transition_to!('waiting_map_location')
          reply(Messages.ask_map_location, reply_markup: map_location_keyboard)
          send_map_browser_link
        when '🌐 Координаты', 'Координаты'
          @session.transition_to!('waiting_coordinates')
          reply(Messages.ask_coordinates, reply_markup: location_input_keyboard)
        when '📝 Описание', 'Описание'
          @session.transition_to!('waiting_text_location')
          reply(Messages.ask_text_location, reply_markup: location_input_keyboard)
        else
          reply('Выберите способ указания места с помощью кнопок.', reply_markup: location_choice_keyboard)
        end
      end

      def handle_map_location
        if @text == '🌐 Ввести координаты'
          @session.transition_to!('waiting_coordinates')
          reply(Messages.ask_coordinates, reply_markup: location_input_keyboard)
          return
        end

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

        if @text && !@text.empty?
          coords = parse_coordinates(@text)
          if coords
            lat, lon = coords
            if valid_coordinates?(lat, lon)
              @bot.api.send_location(chat_id: @chat_id, latitude: lat, longitude: lon)
              save_location('coordinates', lat, lon)
              reply(Messages.coordinates_confirmed(lat, lon))
              return
            end
          end
        end

        reply(
          'Отправьте геопозицию, вставьте координаты из браузера или откройте «🗺 Карта в браузере» в сообщении выше, если мини-приложение не работает.',
          reply_markup: map_location_keyboard
        )
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
          reply(Messages.ask_depth, reply_markup: standard_keyboard)
        when '🔸 Множественная встреча', 'Множественная встреча'
          @session.transition_to!('waiting_encounter_radius', 'encounter_type' => 'multiple_in_radius')
          reply(Messages.ask_encounter_radius, reply_markup: standard_keyboard)
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
        reply(Messages.ask_depth, reply_markup: standard_keyboard)
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
            reply(Messages.need_density_photo, reply_markup: done_keyboard)
            return
          end

          @session.transition_to!('waiting_substrate_type')
          reply(Messages.ask_substrate_type, reply_markup: standard_keyboard)
          return
        end

        if photo_message?
          file_id = photo_file_id
          unless file_id
            reply('❌ Не удалось получить файл. Отправьте изображение ещё раз.', reply_markup: done_keyboard)
            return
          end

          @session.append_photo!(file_id: file_id, photo_type: 'density', caption: @message.caption)
          reply(Messages.photo_added(density_photos.size), reply_markup: done_keyboard)
        else
          reply(Messages.need_photo, reply_markup: done_keyboard)
        end
      end

      # --- substrate ---

      def handle_substrate_type
        return reply('Опишите тип субстрата.', reply_markup: standard_keyboard) if @text.nil? || @text.empty?

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
          file_id = photo_file_id
          unless file_id
            reply(Messages.need_photo, reply_markup: skip_keyboard)
            return
          end

          @session.append_photo!(file_id: file_id, photo_type: 'substrate', caption: @message.caption)
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
          file_id = photo_file_id
          unless file_id
            reply('❌ Не удалось получить файл. Отправьте изображение ещё раз.', reply_markup: finish_keyboard)
            return
          end

          @session.append_photo!(file_id: file_id, photo_type: 'additional', caption: @message.caption)
          reply(Messages.extra_photo_added(additional_photos.size), reply_markup: finish_keyboard)
        else
          reply('Отправьте фото или нажмите «Завершить отчёт».', reply_markup: finish_keyboard)
        end
      end

      def submit_report!
        draft = @session.draft_data
        report = Models::Report.create_from_draft!(@user, draft)
        @session.reset!
        reply(Services::ReportSummary.text(report), parse_mode: nil, reply_markup: start_keyboard)
        send_report_photos(report)
      end

      def send_report_photos(report)
        photos = Models::ReportPhoto.where(report_id: report.id).order(:id).all
        return if photos.empty?

        photos.each_with_index do |photo, index|
          result = @bot.api.send_photo(
            chat_id: @chat_id,
            photo: photo.telegram_file_id,
            caption: Services::ReportSummary.photo_caption(photo, index)
          )
          @session.track_message_id!(result.message_id)
        rescue StandardError => e
          warn "[WARN] Failed to send photo for report ##{report.id}: #{e.message}"
        end
      end

      # --- helpers ---

      def draft
        @session.draft_data
      end

      def start_report_requested?
        @text == '📝 Начать отчёт' || @text == 'Начать отчёт'
      end

      def done_requested?
        return false if photo_message?

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

      def back_requested?
        BACK_COMMANDS.include?(@text&.downcase) || @text == BACK_TEXT
      end

      def change_location_requested?
        @text == CHANGE_LOCATION_TEXT
      end

      def photo_message?
        @message.photo&.any? || @message.document
      end

      def photo_file_id
        if @message.photo&.any?
          @message.photo.max_by { |p| p.file_size || 0 }.file_id
        elsif @message.document
          @message.document.file_id
        end
      end

      def density_photos
        Array(@session.draft_data['photos']).select { |p| p['photo_type'] == 'density' }
      end

      def additional_photos
        Array(@session.draft_data['photos']).select { |p| p['photo_type'] == 'additional' }
      end

      def delete_chat_messages(message_ids)
        message_ids.each do |message_id|
          @bot.api.delete_message(chat_id: @chat_id, message_id: message_id)
        rescue StandardError
          nil
        end
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

      def reply(text, parse_mode: 'Markdown', **options)
        payload = {
          chat_id: @chat_id,
          text: text,
          **options
        }
        payload[:parse_mode] = parse_mode if parse_mode

        result = @bot.api.send_message(**payload)
        @session.track_message_id!(result.message_id)
        result
      end

      # --- keyboards ---

      def keyboard_button(text)
        Telegram::Bot::Types::KeyboardButton.new(text: text)
      end

      def build_keyboard(main_rows, back: true, change_location: false)
        rows = main_rows.dup
        nav_row = []
        nav_row << keyboard_button(BACK_TEXT) if back
        nav_row << keyboard_button(CHANGE_LOCATION_TEXT) if change_location
        rows << nav_row if nav_row.any?
        rows << [keyboard_button('❌ Отмена (/cancel)')]

        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: rows,
          resize_keyboard: true
        )
      end

      def start_keyboard
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [[keyboard_button('📝 Начать отчёт')]],
          resize_keyboard: true,
          one_time_keyboard: false
        )
      end

      def date_keyboard
        build_keyboard([], back: true, change_location: false)
      end

      def location_choice_keyboard
        build_keyboard(
          [
            [keyboard_button('📍 Геопозиция')],
            [keyboard_button('🌐 Координаты')],
            [keyboard_button('📝 Описание')],
            [keyboard_button('🗺 Карта')]
          ],
          back: true,
          change_location: false
        )
      end

      def geolocation_keyboard
        build_keyboard(
          [[Telegram::Bot::Types::KeyboardButton.new(
            text: '📍 Отправить геопозицию',
            request_location: true
          )]],
          back: true,
          change_location: false
        )
      end

      def location_input_keyboard
        build_keyboard([], back: true, change_location: false)
      end

      def map_location_keyboard
        rows = []

        if web_app_url?
          rows << [Telegram::Bot::Types::KeyboardButton.new(
            text: '🗺 Мини-приложение (карта)',
            web_app: Telegram::Bot::Types::WebAppInfo.new(url: web_app_url)
          )]
        end

        rows << [Telegram::Bot::Types::KeyboardButton.new(
          text: '📍 Отправить геопозицию',
          request_location: true
        )]
        rows << [keyboard_button('🌐 Ввести координаты')]

        build_keyboard(rows, back: true, change_location: false)
      end

      def web_app_url
        url = ENV['WEB_APP_URL']
        return nil if url.nil? || url.strip.empty?

        url.strip
      end

      def browser_map_url
        url = web_app_url
        return nil unless url

        url.include?('?') ? "#{url}&browser=1" : "#{url}?browser=1"
      end

      def send_map_browser_link
        url = browser_map_url
        return unless url

        result = @bot.api.send_message(
          chat_id: @chat_id,
          text: Messages.map_browser_hint,
          parse_mode: 'Markdown',
          reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
            inline_keyboard: [
              [Telegram::Bot::Types::InlineKeyboardButton.new(
                text: '🗺 Карта в браузере',
                url: url
              )]
            ]
          )
        )
        @session.track_message_id!(result.message_id)
      end

      def encounter_type_keyboard
        build_keyboard(
          [
            [keyboard_button('🔹 Единичная встреча')],
            [keyboard_button('🔸 Множественная встреча')]
          ],
          back: true,
          change_location: true
        )
      end

      def standard_keyboard
        build_keyboard([], back: true, change_location: true)
      end

      def depth_precision_keyboard
        build_keyboard(
          [
            [keyboard_button('📐 Приблизительная')],
            [keyboard_button('🎯 Точная')]
          ],
          back: true,
          change_location: true
        )
      end

      def done_keyboard
        build_keyboard([[keyboard_button('✅ Готово')]], back: true, change_location: true)
      end

      def skip_keyboard
        build_keyboard([[keyboard_button('⏭ Пропустить')]], back: true, change_location: true)
      end

      def finish_keyboard
        build_keyboard([[keyboard_button('🏁 Завершить отчёт')]], back: true, change_location: true)
      end

      def remove_keyboard
        Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
      end

      def cancel_keyboard
        standard_keyboard
      end
    end
  end
end
