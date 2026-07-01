# frozen_string_literal: true

# Minimal blank/present helpers (subset of ActiveSupport) for plain Ruby bot code.
module DiversBot
  module CoreExt
    module Blank
      module_function

      def blank?(value)
        case value
        when nil, true, false then value.nil? || value == false
        when String then value.strip.empty?
        when Array, Hash then value.empty?
        else
          false
        end
      end

      def present?(value)
        !blank?(value)
      end

      def presence(value)
        present?(value) ? value : nil
      end
    end
  end
end

class Object
  def blank?
    false
  end

  def present?
    !blank?
  end

  def presence
    present? ? self : nil
  end
end

class NilClass
  def blank?
    true
  end

  def present?
    false
  end
end

class FalseClass
  def blank?
    true
  end

  def present?
    false
  end
end

class TrueClass
  def blank?
    false
  end

  def present?
    true
  end
end

class String
  def blank?
    strip.empty?
  end
end

class Array
  def blank?
    empty?
  end
end

class Hash
  def blank?
    empty?
  end
end

class Time
  def beginning_of_day
    Time.new(year, month, day, 0, 0, 0, utc? ? 0 : utc_offset)
  end
end
