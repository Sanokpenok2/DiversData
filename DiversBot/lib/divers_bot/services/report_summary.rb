# frozen_string_literal: true

module DiversBot
  module Services
    module ReportSummary
      module_function

      LOCATION_LABELS = {
        'map_point' => 'Точка на карте',
        'coordinates' => 'Координаты',
        'text_description' => 'Текстовое описание'
      }.freeze

      ENCOUNTER_LABELS = {
        'single' => 'Единичная встреча',
        'multiple_in_radius' => 'Множественная встреча'
      }.freeze

      PHOTO_LABELS = {
        'density' => 'Плотность поселения',
        'substrate' => 'Субстрат',
        'additional' => 'Дополнительное фото'
      }.freeze

      def text(report)
        photos = Array(report.photos)

        lines = []
        lines << '✅ *Отчёт успешно сохранён!*'
        lines << ''
        lines << "🔢 *Номер отчёта: #{report.id}*"
        lines << 'Сохраните или передайте этот номер учёному — по нему отчёт можно найти на сайте DiversData.'
        if (site_url = scientist_site_url)
          lines << "🌐 Сайт: #{site_url}"
        end
        lines << ''
        lines << "📅 Дата наблюдения: #{format_date(report.observation_date)}"
        lines << "📍 Место (#{location_label(report.location_type)}):"
        lines << "   #{format_location(report)}"
        lines << "🔍 Тип встречи: #{format_encounter(report)}"
        lines << "🌊 Глубина: #{format_depth(report)}"
        lines << "🪨 Субстрат: #{report.substrate_type}"
        lines << "ℹ️ Доп. информация: #{report.additional_info || 'не указана'}"
        lines << ''
        lines << '📷 Фотографии:'
        lines << format_photos_list(photos)
        lines << ''
        lines << 'Спасибо за участие в сборе данных!'
        lines << 'Новый отчёт: /start'

        lines.join("\n")
      end

      def format_date(date)
        return date.to_s unless date.respond_to?(:strftime)

        date.strftime('%d.%m.%Y')
      end

      def location_label(type)
        LOCATION_LABELS.fetch(type, type)
      end

      def format_location(report)
        case report.location_type
        when 'text_description'
          report.location_description || '—'
        when 'map_point', 'coordinates'
          if report.latitude && report.longitude
            "широта #{report.latitude.round(6)}, долгота #{report.longitude.round(6)}"
          else
            report.location_description || '—'
          end
        else
          report.location_description || '—'
        end
      end

      def format_encounter(report)
        label = ENCOUNTER_LABELS.fetch(report.encounter_type, report.encounter_type)
        if report.encounter_type == 'multiple_in_radius' && report.encounter_radius_m
          "#{label}, радиус ~#{format_number(report.encounter_radius_m)} м"
        else
          label
        end
      end

      def format_depth(report)
        precision = report.depth_is_approximate ? 'приблизительная' : 'точная'
        "#{format_number(report.depth_m)} м (#{precision})"
      end

      def format_photos_list(photos)
        return '   не добавлены' if photos.empty?

        grouped = photos.group_by(&:photo_type)
        lines = []

        PHOTO_LABELS.each do |type, label|
          items = grouped[type] || []
          next if items.empty?

          lines << "   • #{label}: #{items.size} шт."
          items.each_with_index do |photo, index|
            caption = photo.caption
            lines << if caption && !caption.strip.empty?
                       "     #{index + 1}. подпись: #{caption}"
                     else
                       "     #{index + 1}. без подписи"
                     end
          end
        end

        lines.join("\n")
      end

      def photo_caption(photo, index)
        type_label = PHOTO_LABELS.fetch(photo.photo_type, photo.photo_type)
        parts = ["#{type_label} (#{index + 1})"]
        parts << photo.caption if photo.caption && !photo.caption.strip.empty?
        parts.join("\n")
      end

      def format_number(value)
        return value.to_i.to_s if value == value.to_i

        value.to_s
      end

      def scientist_site_url
        url = ENV['SCIENTIST_WEB_URL']
        return nil if url.nil? || url.strip.empty?

        url.strip
      end
    end
  end
end
