# frozen_string_literal: true

class Api::V1::MerchantsController < Api::V1::BaseController
  before_action :ensure_read_scope
  before_action :ensure_write_scope, only: [ :create, :update, :destroy ]
  before_action :set_merchant, only: [ :update, :destroy ]

  def index
    family = current_resource_owner.family
    merchants = family.merchants.alphabetically

    render json: {
      merchants: merchants.map { |merchant| render_merchant(merchant) }
    }
  rescue => e
    Rails.logger.error "MerchantsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def create
    family = current_resource_owner.family

    @merchant = FamilyMerchant.new(merchant_params.merge(family: family))

    if @merchant.save
      render json: render_merchant(@merchant), status: :created
    else
      render json: {
        error: "validation_error",
        message: @merchant.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "MerchantsController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def update
    if @merchant.update(merchant_params)
      render json: render_merchant(@merchant)
    else
      render json: {
        error: "validation_error",
        message: @merchant.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "MerchantsController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def destroy
    @merchant.destroy!
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: "not_found",
      message: "Merchant not found"
    }, status: :not_found
  rescue => e
    Rails.logger.error "MerchantsController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  private

    def set_merchant
      family = current_resource_owner.family
      @merchant = family.merchants.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Merchant not found"
      }, status: :not_found
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def merchant_params
      params.permit(:name, :color)
    end

    def render_merchant(merchant)
      {
        id: merchant.id,
        name: merchant.name,
        color: merchant.color,
        created_at: merchant.created_at.iso8601
      }
    end
end
