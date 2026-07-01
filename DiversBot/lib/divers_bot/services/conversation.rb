# frozen_string_literal: true

require 'max_bot_api'

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

      def initialize(client, message)
        @client = client
        @message = message
        @user = message.from
        @session = Models::UserSession.find_or_create_for(@user)
        @chat_id = resolve_chat_id(message)
        @session.remember_chat_id!(@chat_id) if @chat_id
        @text = message.text&.strip
        @spam_guard = SpamGuard.new(@user.id)
      end

      def handle
        @session.track_message_id!(@message.message_id) if @message.message_id
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
        reply(Messages.cancelled, reply_markup: start_keyboard)
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

      def handle_location_choice
        case @text
        when '📍 Геопозиция', 'Геопозиция'
          @session.transition_to!('waiting_map_location')
          reply(Messages.ask_geolocation, reply_markup: geolocation_keyboard)
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
        if @message.location
          loc = @message.location
          save_location('map_point', loc.latitude, loc.longitude)
          return
        end

        reply(Messages.ask_geolocation, reply_markup: geolocation_keyboard)
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

        send_location(lat, lon)
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
          token = photo_attachment_token
          source_url = @message.photo_attachment_url
          unless token || source_url
            reply('❌ Не удалось получить файл. Отправьте изображение ещё раз.', reply_markup: done_keyboard)
            return
          end

          @session.append_photo!(
            attachment_token: token.presence || source_url,
            source_url: source_url,
            photo_type: 'density',
            caption: @message.caption
          )
          reply(Messages.photo_added(density_photos.size), reply_markup: done_keyboard)
        else
          reply(Messages.need_photo, reply_markup: done_keyboard)
        end
      end

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
          token = photo_attachment_token
          source_url = @message.photo_attachment_url
          unless token || source_url
            reply(Messages.need_photo, reply_markup: skip_keyboard)
            return
          end

          @session.append_photo!(
            attachment_token: token.presence || source_url,
            source_url: source_url,
            photo_type: 'substrate',
            caption: @message.caption
          )
          @session.transition_to!('waiting_additional_info')
          reply(Messages.ask_additional_info, reply_markup: skip_keyboard)
        else
          reply(Messages.need_photo, reply_markup: skip_keyboard)
        end
      end

      def handle_additional_info
        unless skip_requested?
          @session.transition_to!('waiting_extra_photos', 'additional_info' => @text) if @text && !@text.empty?
        end

        if @session.state == 'waiting_additional_info'
          @session.transition_to!('waiting_extra_photos', 'additional_info' => nil)
        end

        reply(Messages.ask_extra_photos, reply_markup: finish_keyboard)
      end

      def handle_extra_photos
        if finish_requested?
          submit_report!
          return
        end

        if photo_message?
          token = photo_attachment_token
          source_url = @message.photo_attachment_url
          unless token || source_url
            reply('❌ Не удалось получить файл. Отправьте изображение ещё раз.', reply_markup: finish_keyboard)
            return
          end

          @session.append_photo!(
            attachment_token: token.presence || source_url,
            source_url: source_url,
            photo_type: 'additional',
            caption: @message.caption
          )
          reply(Messages.extra_photo_added(additional_photos.size), reply_markup: finish_keyboard)
        else
          reply('Отправьте фото или нажмите «Завершить отчёт».', reply_markup: finish_keyboard)
        end
      end

      def submit_report!
        draft = @session.draft_data
        report = Models::Report.create_from_draft!(@user, draft)
        @session.reset!
        reply(Services::ReportSummary.text(report), format: 'markdown', reply_markup: start_keyboard)
        send_report_photos(report)
      end

      def send_report_photos(report)
        photos = Models::ReportPhoto.where(report_id: report.id).order(:id).all
        return if photos.empty?

        photos.each_with_index do |photo, index|
          caption = Services::ReportSummary.photo_caption(photo, index)
          message = MaxBotApi::Builders::MessageBuilder.new
                                                       .set_text(caption.to_s)
                                                       .add_photo_by_token(photo.attachment_token)
          apply_recipient!(message)
          result = @client.messages.send_with_result(message)
          mid = result&.dig(:body, :mid)
          @session.track_message_id!(mid) if mid
        rescue StandardError => e
          warn "[WARN] Failed to send photo for report ##{report.id}: #{e.message}"
        end
      end

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
        @message.photo_message?
      end

      def photo_attachment_token
        @message.photo_attachment_token
      end

      def density_photos
        Array(@session.draft_data['photos']).select { |p| p['photo_type'] == 'density' }
      end

      def additional_photos
        Array(@session.draft_data['photos']).select { |p| p['photo_type'] == 'additional' }
      end

      def delete_chat_messages(message_ids)
        message_ids.each do |message_id|
          @client.messages.delete_message(message_id: message_id.to_s)
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

      def reply(text, format: 'markdown', reply_markup: nil)
        message = MaxBotApi::Builders::MessageBuilder.new
                                                     .set_text(text)
        message.set_format(format) if format
        apply_recipient!(message)

        keyboard = reply_markup || standard_keyboard_for_state
        message.add_keyboard(keyboard) if keyboard

        result = @client.messages.send_with_result(message)
        mid = result&.dig(:body, :mid)
        @session.track_message_id!(mid) if mid
        result
      end

      def send_location(lat, lon)
        message = MaxBotApi::Builders::MessageBuilder.new
                                                     .add_location(lat, lon)
        apply_recipient!(message)
        result = @client.messages.send_with_result(message)
        mid = result&.dig(:body, :mid)
        @session.track_message_id!(mid) if mid
      end

      def resolve_chat_id(message)
        message.chat.id || @session.stored_chat_id
      end

      def apply_recipient!(builder)
        if @chat_id && @chat_id.to_i != 0
          builder.set_chat(@chat_id)
        elsif @user.id && @user.id.to_i != 0
          builder.set_user(@user.id)
        end
        builder
      end

      def standard_keyboard_for_state
        nil
      end

      # --- keyboards (MAX inline) ---

      def build_keyboard(main_rows, back: true, change_location: false)
        kb = @client.messages.new_keyboard_builder

        main_rows.each do |row_texts|
          row = kb.add_row
          row_texts.each { |label| row.add_message(label) }
        end

        nav = []
        nav << BACK_TEXT if back
        nav << CHANGE_LOCATION_TEXT if change_location
        nav << '❌ Отмена (/cancel)'

        row = kb.add_row
        nav.each { |label| row.add_message(label) }
        kb
      end

      def start_keyboard
        kb = @client.messages.new_keyboard_builder
        kb.add_row.add_message('📝 Начать отчёт')
        kb
      end

      def date_keyboard
        build_keyboard([], back: true, change_location: false)
      end

      def location_choice_keyboard
        build_keyboard(
          [
            ['📍 Геопозиция'],
            ['🌐 Координаты'],
            ['📝 Описание']
          ],
          back: true,
          change_location: false
        )
      end

      def geolocation_keyboard
        kb = @client.messages.new_keyboard_builder
        row = kb.add_row
        add_geo_button(row, '📍 Отправить геопозицию')
        row = kb.add_row
        row.add_message(BACK_TEXT)
        row.add_message('❌ Отмена (/cancel)')
        kb
      end

      def location_input_keyboard
        build_keyboard([], back: true, change_location: false)
      end

      def add_geo_button(row, text)
        row.add_geolocation(text, true)
      end

      def encounter_type_keyboard
        build_keyboard(
          [
            ['🔹 Единичная встреча'],
            ['🔸 Множественная встреча']
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
            ['📐 Приблизительная'],
            ['🎯 Точная']
          ],
          back: true,
          change_location: true
        )
      end

      def done_keyboard
        build_keyboard([['✅ Готово']], back: true, change_location: true)
      end

      def skip_keyboard
        build_keyboard([['⏭ Пропустить']], back: true, change_location: true)
      end

      def finish_keyboard
        build_keyboard([['🏁 Завершить отчёт']], back: true, change_location: true)
      end
    end
  end
end
