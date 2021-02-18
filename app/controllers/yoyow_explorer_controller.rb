# frozen_string_literal: true

require 'openssl'
require 'json'

require_dependency 'application_controller'

class ::YoyowRetorts::YoyowExplorerController < ApplicationController
  def get_accounts_posts
    if current_user.username_lower == params[:username].downcase
      limit = params[:limit] || 10
      offset = params[:offset] || 0

      user_id = User.select(:id).find_by_username_lower(params[:username].downcase).id
      yoyow_id = UserAssociatedAccount.find_by(provider_name:"yoyow", user_id: user_id).provider_uid
      if yoyow_id.blank?
        render json: {
          code: 404,
          msg:"RECORDS Not Found"
        }
      else
        render json: ::YoyowRetorts::YoyowMiddlewareAPI.instance.get_accounts_posts(yoyow_id, SiteSetting.yoyow_platform_id, offset, limit)
      end
    else
      render json: {
        code: 403,
        msg:"Not Allowed"
      }
    end
  end

  def get_accounts_scores
    if current_user.username_lower == params[:username].downcase
      limit = params[:limit] || 10
      offset = params[:offset] || 0
      user_id = current_user.id
      yoyow_id = UserAssociatedAccount.find_by(provider_name:"yoyow", user_id: user_id)&.provider_uid
      if yoyow_id.blank?
        render json: {
          code: 404,
          msg:"RECORDS Not Found"
        }
      else
        render json: ::YoyowRetorts::YoyowMiddlewareAPI.instance.get_accounts_scores(yoyow_id, SiteSetting.yoyow_platform_id, offset, limit)
      end
    else
      render json: {
        code: 403,
        msg:"Not Allowed"
      }
    end
  end

end
