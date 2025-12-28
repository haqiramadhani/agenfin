# frozen_string_literal: true

class Api::V1::ReportsController < Api::V1::BaseController
  before_action :ensure_read_scope

  def net_worth
    family = current_resource_owner.family
    period_type = params[:period_type]&.to_sym || :monthly
    months = [ params[:months]&.to_i, 6 ].compact.min

    # Calculate period dates
    start_date = months.months.ago.beginning_of_month.to_date
    end_date = Date.current.end_of_month.to_date

    # Get balance sheet data
    balance_sheet = family.balance_sheet

    # Build net worth series
    series = build_net_worth_series(family, start_date, end_date, period_type)

    render json: {
      period: {
        start_date: start_date.iso8601,
        end_date: end_date.iso8601
      },
      current_net_worth: balance_sheet.net_worth_money.format,
      series: series
    }
  rescue => e
    Rails.logger.error "ReportsController#net_worth error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def cashflow
    family = current_resource_owner.family

    # Parse date range
    start_date = parse_date_param(:start_date) || Date.current.beginning_of_month.to_date
    end_date = parse_date_param(:end_date) || Date.current.to_date
    period = Period.custom(start_date: start_date, end_date: end_date)

    # Get income and expense totals
    income_totals = family.income_statement.income_totals(period: period)
    expense_totals = family.income_statement.expense_totals(period: period)
    net_savings = income_totals.total - expense_totals.total

    # Get category breakdown
    by_category = build_category_breakdown(family, period)

    # Build monthly breakdown
    monthly_breakdown = build_monthly_breakdown(family, start_date, end_date)

    render json: {
      period: {
        start_date: start_date.iso8601,
        end_date: end_date.iso8601
      },
      totals: {
        income: income_totals.total_money.format,
        expenses: expense_totals.total_money.format,
        net_savings: net_savings.format
      },
      by_category: by_category,
      monthly_breakdown: monthly_breakdown
    }
  rescue => e
    Rails.logger.error "ReportsController#cashflow error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def balance_sheet
    family = current_resource_owner.family
    balance_sheet = family.balance_sheet

    # Group assets by account type
    asset_groups = balance_sheet.assets.account_groups.group_by(&:key)

    render json: {
      as_of: Time.current.iso8601,
      assets: {
        total: balance_sheet.assets.total_money.format,
        breakdown: asset_groups.transform_values { |groups| groups.sum(&:total_money).format }
      },
      liabilities: {
        total: balance_sheet.liabilities.total_money.format,
        breakdown: balance_sheet.liabilities.account_groups.group_by(&:key).transform_values { |groups| groups.sum(&:total_money).format }
      },
      net_worth: balance_sheet.net_worth_money.format
    }
  rescue => e
    Rails.logger.error "ReportsController#balance_sheet error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def outflows
    family = current_resource_owner.family

    # Parse date range
    start_date = parse_date_param(:start_date) || Date.current.beginning_of_month.to_date
    end_date = parse_date_param(:end_date) || Date.current.to_date
    limit = [ params[:limit]&.to_i, 50 ].compact.min || 10
    period = Period.custom(start_date: start_date, end_date: end_date)

    # Get expense breakdown by category
    top_outflows = build_top_outflows(family, period, limit)

    render json: {
      period: {
        start_date: start_date.iso8601,
        end_date: end_date.iso8601
      },
      top_outflows: top_outflows
    }
  rescue => e
    Rails.logger.error "ReportsController#outflows error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def parse_date_param(param_name)
      date_string = params[param_name]
      return nil if date_string.blank?

      Date.parse(date_string)
    rescue Date::Error
      nil
    end

    def build_net_worth_series(family, start_date, end_date, period_type)
      series = []
      current_month = start_date.beginning_of_month

      while current_month <= end_date
        month_end = [ current_month.end_of_month, end_date ].min

        # Calculate net worth at end of this month
        net_worth = family.balance_sheet.net_worth_money
        assets = family.balance_sheet.assets_money
        liabilities = family.balance_sheet.liabilities_money

        series << {
          date: month_end.iso8601,
          net_worth: net_worth.format,
          assets: assets.format,
          liabilities: liabilities.format
        }

        current_month = current_month.next_month
      end

      series
    end

    def build_category_breakdown(family, period)
      breakdown = []

      # Get income by category
      income_totals = family.income_statement.income_totals(period: period)
      income_totals.category_totals.each do |ct|
        breakdown << {
          category: ct.category.name,
          type: "income",
          total: ct.total.format
        }
      end

      # Get expenses by category
      expense_totals = family.income_statement.expense_totals(period: period)
      expense_totals.category_totals.each do |ct|
        breakdown << {
          category: ct.category.name,
          type: "expense",
          total: ct.total.format
        }
      end

      breakdown.sort_by { |item| item[:type] == "income" ? -item[:total].to_f : 0 }
    end

    def build_monthly_breakdown(family, start_date, end_date)
      breakdown = []
      current_month = start_date.beginning_of_month

      while current_month <= end_date
        month_start = current_month
        month_end = [ current_month.end_of_month, end_date ].min
        month_period = Period.custom(start_date: month_start, end_date: month_end)

        income = family.income_statement.income_totals(period: month_period).total
        expenses = family.income_statement.expense_totals(period: month_period).total

        breakdown << {
          month: month_start.strftime("%b %Y"),
          income: income.format,
          expenses: expenses.format,
          net: (income - expenses).format
        }

        current_month = current_month.next_month
      end

      breakdown
    end

    def build_top_outflows(family, period, limit)
      # Get expenses by category
      expense_totals = family.income_statement.expense_totals(period: period)
      total_expenses = expense_totals.total

      top_outflows = expense_totals.category_totals
        .reject { |ct| ct.category.subcategory? }
        .sort_by { |ct| -ct.total }
        .first(limit)
        .map do |ct|
        {
          category: ct.category.name,
          amount: ct.total.format,
          percentage: total_expenses.positive? ? ((ct.total / total_expenses) * 100).round(1) : 0
        }
      end

      # Add transaction counts
      top_outflows.each do |outflow|
        category_name = outflow[:category]
        category = family.categories.find_by(name: category_name)

        count = family.transactions
          .joins(:entry)
          .where(entries: { date: period.date_range })
          .where(category: category)
          .where("entries.amount > 0")
          .count

        outflow[:transaction_count] = count
      end

      top_outflows
    end
end
