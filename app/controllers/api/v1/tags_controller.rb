# frozen_string_literal: true

class Api::V1::TagsController < Api::V1::BaseController
  before_action :ensure_read_scope
  before_action :ensure_write_scope, only: [ :create, :update, :destroy ]
  before_action :set_tag, only: [ :update, :destroy ]

  def index
    family = current_resource_owner.family
    tags = family.tags.alphabetically

    render json: {
      tags: tags.map { |tag| render_tag(tag) }
    }
  rescue => e
    Rails.logger.error "TagsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def create
    family = current_resource_owner.family

    @tag = family.tags.new(tag_params)

    if @tag.save
      render json: render_tag(@tag), status: :created
    else
      render json: {
        error: "validation_error",
        message: @tag.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "TagsController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def update
    if @tag.update(tag_params)
      render json: render_tag(@tag)
    else
      render json: {
        error: "validation_error",
        message: @tag.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "TagsController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def destroy
    @tag.destroy!
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: "not_found",
      message: "Tag not found"
    }, status: :not_found
  rescue => e
    Rails.logger.error "TagsController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  private

    def set_tag
      family = current_resource_owner.family
      @tag = family.tags.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Tag not found"
      }, status: :not_found
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def tag_params
      params.permit(:name, :color)
    end

    def render_tag(tag)
      {
        id: tag.id,
        name: tag.name,
        color: tag.color,
        created_at: tag.created_at.iso8601
      }
    end
end
