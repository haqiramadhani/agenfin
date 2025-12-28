# frozen_string_literal: true

class Api::V1::CategoriesController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope
  before_action :ensure_write_scope, only: [ :create, :update, :destroy ]
  before_action :set_category, only: [ :show, :update, :destroy ]

  def index
    family = current_resource_owner.family
    categories_query = family.categories.includes(:parent, :subcategories).alphabetically

    # Apply filters
    categories_query = apply_filters(categories_query)

    # Handle pagination with Pagy
    @pagy, @categories = pagy(
      categories_query,
      page: safe_page_param,
      limit: safe_per_page_param
    )

    @per_page = safe_per_page_param

    render :index
  rescue => e
    Rails.logger.error "CategoriesController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def show
    render :show
  rescue => e
    Rails.logger.error "CategoriesController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def create
    family = current_resource_owner.family

    @category = family.categories.new(category_params)

    if @category.save
      render json: {
        id: @category.id,
        name: @category.name,
        type: @category.classification,
        color: @category.color,
        icon: @category.lucide_icon,
        parent_id: @category.parent_id,
        created_at: @category.created_at.iso8601
      }, status: :created
    else
      render json: {
        error: "validation_error",
        message: @category.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "CategoriesController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def update
    if @category.update(category_params)
      render json: {
        id: @category.id,
        name: @category.name,
        type: @category.classification,
        color: @category.color,
        icon: @category.lucide_icon,
        parent_id: @category.parent_id,
        updated_at: @category.updated_at.iso8601
      }
    else
      render json: {
        error: "validation_error",
        message: @category.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "CategoriesController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def destroy
    @category.destroy!
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: "not_found",
      message: "Category not found"
    }, status: :not_found
  rescue => e
    Rails.logger.error "CategoriesController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  private

    def set_category
      family = current_resource_owner.family
      @category = family.categories.includes(:parent, :subcategories).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Category not found"
      }, status: :not_found
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def category_params
      params.permit(:name, :color, :parent_id, :classification, :lucide_icon)
    end

    def apply_filters(query)
      # Filter by classification (income/expense)
      if params[:classification].present?
        query = query.where(classification: params[:classification])
      end

      # Filter for root categories only (no parent)
      if params[:roots_only].present? && ActiveModel::Type::Boolean.new.cast(params[:roots_only])
        query = query.roots
      end

      # Filter by parent_id
      if params[:parent_id].present?
        query = query.where(parent_id: params[:parent_id])
      end

      query
    end

    def safe_page_param
      page = params[:page].to_i
      page > 0 ? page : 1
    end

    def safe_per_page_param
      per_page = params[:per_page].to_i

      case per_page
      when 1..100
        per_page
      else
        25
      end
    end
end
