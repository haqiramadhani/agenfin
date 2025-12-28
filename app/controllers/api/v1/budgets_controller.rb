# frozen_string_literal: true

class Api::V1::BudgetsController < Api::V1::BaseController
  before_action :ensure_read_scope
  before_action :ensure_write_scope, only: [ :update ]
  before_action :set_budget, only: [ :show, :update ]

  def index
    family = current_resource_owner.family

    # Parse month param or use current month
    if params[:month].present?
      start_date = Budget.param_to_date(params[:month])
      if start_date.nil?
        render json: {
          error: "invalid_month",
          message: "Invalid month format. Use YYYY-MM."
        }, status: :bad_request
        return
      end
    else
      start_date = Date.current.beginning_of_month
    end

    budget = family.budgets.find_by(start_date: start_date)

    if budget
      render_budget(budget)
    else
      # Return empty response if no budget exists for the month
      render json: {
        budgets: []
      }
    end
  rescue => e
    Rails.logger.error "BudgetsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def show
    render_budget(@budget)
  rescue => e
    Rails.logger.error "BudgetsController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def update
    # Update budget level fields
    if params[:budgeted_spending].present? || params[:expected_income].present?
      @budget.update!(
        budget_params.slice(:budgeted_spending, :expected_income)
      )
    end

    # Update budget categories if provided
    if params[:categories].present?
      update_budget_categories
    end

    render_budget(@budget)
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: "validation_error",
      message: e.message,
      details: e.record.errors.full_messages
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "BudgetsController#update error: #{e.message}"
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

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def set_budget
      family = current_resource_owner.family

      if params[:month_year].present?
        start_date = Budget.param_to_date(params[:month_year])
      elsif params[:id].present? && params[:id] =~ /\A[0-9a-f]{8}-[0-9a-f]{4}/i
        # If id looks like a UUID, try to find by id
        @budget = family.budgets.find_by(id: params[:id])
        return if @budget

        render json: {
          error: "not_found",
          message: "Budget not found"
        }, status: :not_found
        return
      else
        start_date = Date.current.beginning_of_month
      end

      @budget = family.budgets.find_by(start_date: start_date)

      unless @budget
        render json: {
          error: "not_found",
          message: "Budget not found"
        }, status: :not_found
      end
    end

    def budget_params
      params.permit(:budgeted_spending, :expected_income)
    end

    def update_budget_categories
      categories_data = params[:categories]

      ActiveRecord::Base.transaction do
        categories_data.each do |category_id, category_params|
          budget_category = @budget.budget_categories.find_by(category_id: category_id)
          next unless budget_category

          if category_params[:budgeted_spending].present?
            budget_category.update!(
              budgeted_spending: category_params[:budgeted_spending]
            )
          end
        end
      end
    end

    def render_budget(budget)
      budget_categories = budget.budget_categories.includes(:category).map do |bc|
        {
          id: bc.category.id,
          name: bc.category.name,
          budgeted: bc.budgeted_spending_money.format,
          spent: bc.actual_spending_money.format,
          remaining: bc.available_to_spend_money.format,
          percent_spent: bc.percent_of_budget_spent
        }
      end

      render json: {
        budgets: [
          {
            id: budget.id,
            start_date: budget.start_date.iso8601,
            end_date: budget.end_date.iso8601,
            currency: budget.currency,
            budgeted_spending: budget.budgeted_spending_money.format,
            expected_income: budget.expected_income_money.format,
            actual_spending: budget.actual_spending_money.format,
            allocated_spending: budget.allocated_spending_money.format,
            available_to_spend: budget.available_to_spend_money.format,
            percent_spent: budget.percent_of_budget_spent,
            categories: budget_categories
          }
        ]
      }
    end
end
