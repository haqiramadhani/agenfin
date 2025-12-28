# frozen_string_literal: true

class Api::V1::AccountsController < Api::V1::BaseController
  include Pagy::Backend

  # Ensure proper scope authorization for read access
  before_action :ensure_read_scope, only: [ :index ]
  before_action :ensure_write_scope, only: [ :create ]

  def index
    # Test with Pagy pagination
    family = current_resource_owner.family
    accounts_query = family.accounts.visible.alphabetically

    # Handle pagination with Pagy
    @pagy, @accounts = pagy(
      accounts_query,
      page: safe_page_param,
      limit: safe_per_page_param
    )

    @per_page = safe_per_page_param

    # Rails will automatically use app/views/api/v1/accounts/index.json.jbuilder
    render :index
  rescue => e
    Rails.logger.error "AccountsController error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def create
    family = current_resource_owner.family

    # Only allow checking and savings accounts via API
    allowed_types = %w[checking savings]
    accountable_type = params[:accountable_type]

    unless allowed_types.include?(accountable_type)
      render json: {
        error: "invalid_account_type",
        message: "Only checking and savings accounts can be created via API"
      }, status: :bad_request
      return
    end

    account = Account.create_and_sync(
      name: params[:name],
      family: family,
      balance: params[:balance] || 0,
      currency: params[:currency] || family.currency,
      accountable_type: "Depository",
      accountable_attributes: {
        subtype: accountable_type
      }
    )

    render json: {
      id: account.id,
      name: account.name,
      balance: account.balance_money.format,
      currency: account.currency,
      classification: account.classification,
      account_type: account.accountable.subtype,
      created_at: account.created_at.iso8601
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: "validation_error",
      message: e.message,
      details: e.record.errors.full_messages
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "AccountsController#create error: #{e.message}"
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

    def safe_page_param
      page = params[:page].to_i
      page > 0 ? page : 1
    end

    def safe_per_page_param
      per_page = params[:per_page].to_i

      # Default to 25, max 100
      case per_page
      when 1..100
        per_page
      else
        25
      end
    end
end
