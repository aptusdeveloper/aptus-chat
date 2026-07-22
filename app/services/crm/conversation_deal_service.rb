module Crm
  class ConversationDealService
    def initialize(conversation)
      @conversation = conversation
      @account = conversation.account
    end

    def perform
      pipeline = @account.crm_pipelines.find_by(is_default: true)
      return unless pipeline

      first_stage = pipeline.crm_stages.where(is_win: false, is_loss: false).order(:position).first
      return unless first_stage

      deal = @account.crm_deals.create!(
        name: deal_name,
        crm_pipeline: pipeline,
        crm_stage: first_stage,
        contact_id: @conversation.contact_id
      )
      CrmDealConversation.create!(crm_deal: deal, conversation: @conversation)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Crm::ConversationDealService: failed for conversation #{@conversation.id} — #{e.message}"
    end

    private

    def deal_name
      @conversation.contact&.name.presence || "##{@conversation.display_id}"
    end
  end
end
