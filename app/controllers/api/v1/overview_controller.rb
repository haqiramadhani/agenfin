# frozen_string_literal: true

class Api::V1::OverviewController < Api::V1::BaseController
  before_action :ensure_read_scope

  def show
    family = current_resource_owner.family
    period_type = params[:period_type]&.to_sym || :monthly

    # Calculate period dates
    start_date, end_date = calculate_period_dates(period_type)
    period = Period.custom(start_date: start_date, end_date: end_date)

    # Get income statement data
    income_totals = family.income_statement.income_totals(period: period)
    expense_totals = family.income_statement.expense_totals(period: period)

    # Calculate net savings
    net_savings = income_totals.total - expense_totals.total

    # Get budget for current month
    budget = Budget.find_or_bootstrap(family, start_date: Date.current.beginning_of_month)

    # Get account counts and transaction counts
    accounts_count = family.accounts.visible.count
    transactions_count = family.transactions
      .joins(:entry)
      .where(entries: { date: period.date_range })
      .count

    render json: {
      period: {
        start_date: start_date.iso8601,
        end_date: end_date.iso8601,
        period_type: period_type.to_s
      },
      net_worth: family.balance_sheet.net_worth_money.format,
      accounts_count: accounts_count,
      transactions_count: transactions_count,
      current_month: {
        income: income_totals.total_money.format,
        expenses: expense_totals.total_money.format,
        net_savings: net_savings.format
      },
      budget: budget ? {
        budgeted: budget.budgeted_spending_money.format,
        spent: budget.actual_spending_money.format,
        remaining: budget.available_to_spend_money.format,
        percent_used: budget.percent_of_budget_spent
      } : nil
    }
  rescue => e
    Rails.logger.error "OverviewController error: #{e.message}"
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

    def calculate_period_dates(period_type)
      case period_type
      when :monthly
        [ Date.current.beginning_of_month.to_date, Date.current.end_of_month.to_date ]
      when :quarterly
        [ Date.current.beginning_of_quarter.to_date, Date.current.end_of_quarter.to_date ]
      when :ytd
        [ Date.current.beginning_of_year.to_date, Date.current.to_date ]
      else
        [ Date.current.beginning_of_month.to_date, Date.current.end_of_month.to_date ]
      end
    end
end
