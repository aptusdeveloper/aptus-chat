# == Schema Information
#
# Table name: crm_deal_conversations
#
#  id              :uuid             not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :bigint           not null
#  crm_deal_id     :uuid             not null
#
# Indexes
#
#  idx_on_crm_deal_id_conversation_id_71bc7ef779    (crm_deal_id,conversation_id) UNIQUE
#  index_crm_deal_conversations_on_conversation_id  (conversation_id)
#  index_crm_deal_conversations_on_crm_deal_id      (crm_deal_id)
#
# Foreign Keys
#
#  fk_rails_...  (crm_deal_id => crm_deals.id)
#
class CrmDealConversation < ApplicationRecord
  belongs_to :crm_deal
  belongs_to :conversation

  validates :conversation_id, uniqueness: { scope: :crm_deal_id }
end

CrmDealConversation.prepend_mod_with('CrmDealConversation')
