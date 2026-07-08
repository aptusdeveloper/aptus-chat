# == Schema Information
#
# Table name: crm_automation_executions
#
#  id                     :uuid             not null, primary key
#  error_message          :text
#  executed_at            :datetime         not null
#  status                 :string           not null
#  trigger_type           :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  crm_automation_rule_id :uuid             not null
#  crm_deal_id            :uuid             not null
#
# Indexes
#
#  idx_crm_executions_idempotency                                  (crm_deal_id,crm_automation_rule_id,executed_at)
#  idx_on_crm_automation_rule_id_status_a04a609b54                 (crm_automation_rule_id,status)
#  index_crm_automation_executions_on_crm_automation_rule_id       (crm_automation_rule_id)
#  index_crm_automation_executions_on_crm_deal_id                  (crm_deal_id)
#  index_crm_automation_executions_on_crm_deal_id_and_executed_at  (crm_deal_id,executed_at)
#
# Foreign Keys
#
#  fk_rails_...  (crm_automation_rule_id => crm_automation_rules.id)
#  fk_rails_...  (crm_deal_id => crm_deals.id)
#
class CrmAutomationExecution < ApplicationRecord
  STATUSES = %w[success failed].freeze

  belongs_to :crm_automation_rule
  belongs_to :crm_deal

  validates :trigger_type, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :executed_at, presence: true

  scope :today, -> { where(executed_at: Time.current.all_day) }
  scope :successful, -> { where(status: 'success') }
  scope :failed, -> { where(status: 'failed') }
end

CrmAutomationExecution.prepend_mod_with('CrmAutomationExecution')
