# frozen_string_literal: true

class ReportListPagination
  PER_PAGE_OPTIONS = [10, 25, 50, 100].freeze
  DEFAULT_PER_PAGE = 25

  attr_reader :page, :per_page, :total, :total_pages

  def initialize(page:, per_page:, total:)
    @per_page = normalize_per_page(per_page)
    @total = total.to_i
    @total_pages = @total.zero? ? 1 : (@total.to_f / @per_page).ceil
    @page = normalize_page(page)
  end

  def offset
    (@page - 1) * @per_page
  end

  def showing_from
    return 0 if total.zero?

    offset + 1
  end

  def showing_to
    [offset + per_page, total].min
  end

  def first_page?
    page <= 1
  end

  def last_page?
    page >= total_pages
  end

  def page_window(radius: 2)
    start_page = [page - radius, 1].max
    end_page = [page + radius, total_pages].min
    (start_page..end_page).to_a
  end

  private

  def normalize_per_page(value)
    per_page = value.to_i
    PER_PAGE_OPTIONS.include?(per_page) ? per_page : DEFAULT_PER_PAGE
  end

  def normalize_page(value)
    page_number = value.to_i
    page_number = 1 if page_number < 1
    [page_number, total_pages].min
  end
end
