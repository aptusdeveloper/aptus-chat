class Api::V1::Accounts::AptusHubController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :ensure_hub_available!

  rescue_from AptusHub::BotpressClient::Error, with: :render_hub_error
  rescue_from AptusHub::ExchangeRateClient::Error, with: :render_hub_error

  def performance
    render json: portal_service.performance(from: period_from, to: period_to)
  end

  def webchat_config
    render json: portal_service.webchat_config
  end

  def payments
    render json: portal_service.payments
  end

  def payment_details
    render json: portal_service.payment_details(month: params[:month])
  end

  def feedback
    render json: portal_service.create_feedback!(
      conversation_id: feedback_conversation_id,
      comment: feedback_comment
    )
  end

  private

  def check_authorization
    authorize(:aptus_hub)
  end

  def ensure_hub_available!
    return if hub_config.available?

    render json: { error: 'Hub Aptus nao configurado para esta conta.' }, status: :not_found
  end

  def hub_config
    @hub_config ||= AptusHub::AccountConfig.new(Current.account)
  end

  def portal_service
    @portal_service ||= AptusHub::CustomerPortalService.new(
      account: Current.account,
      user: Current.user
    )
  end

  def period_from
    parse_date(params[:from]) || Time.zone.today.beginning_of_month
  end

  def period_to
    parse_date(params[:to]) || Time.zone.today
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def feedback_conversation_id
    params[:conversation_id].presence ||
      params[:conversationId].presence ||
      params.require(:conversation_id)
  end

  def feedback_comment
    params[:comment].presence ||
      params[:comentario].presence ||
      params.require(:comment)
  end

  def render_hub_error(error)
    render json: { error: error.message }, status: :bad_gateway
  end
end
