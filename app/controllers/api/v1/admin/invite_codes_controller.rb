# frozen_string_literal: true

class Api::V1::Admin::InviteCodesController < Api::V1::BaseController
  before_action :ensure_write_scope

  def create
    unless current_resource_owner.superadmin?
      render json: {
        error: "forbidden",
        message: "Only superadmins can create invite codes"
      }, status: :forbidden
      return
    end

    token = InviteCode.generate!

    render json: {
      token: token,
      created_at: Time.current.iso8601
    }, status: :created
  end

  private

    def ensure_write_scope
      authorize_scope!(:write)
    end
end
