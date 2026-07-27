class Api::V1::Accounts::CrmDealsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_deal, only: [:show, :update, :destroy, :move]

  def index
    deals = Current.account.crm_deals
    deals = deals.where(crm_pipeline_id: params[:pipeline_id]) if params[:pipeline_id].present?
    deals = deals.where(crm_stage_id: params[:stage_id]) if params[:stage_id].present?
    @deals = deals.includes(:assignee, contact: { conversations: [:assignee, :team, :inbox] }).order(:position)
  end

  def show; end

  def create
    @deal = Current.account.crm_deals.build(deal_params)
    @deal.save!
  end

  def update
    @deal.update!(deal_params)
  end

  def destroy
    @deal.destroy!
    head :ok
  end

  def move
    @deal.update!(
      crm_stage_id: params.require(:stage_id),
      position: params.fetch(:position, @deal.position)
    )
  end

  private

  def fetch_deal
    @deal = Current.account.crm_deals.includes(:assignee, contact: { conversations: [:assignee, :team, :inbox] }).find(params[:id])
  end

  def deal_params
    params.require(:crm_deal).permit(
      :name, :amount, :currency, :close_date, :probability,
      :position, :crm_pipeline_id, :crm_stage_id, :contact_id, :assignee_id,
      custom_attributes: {}
    )
  end
end
