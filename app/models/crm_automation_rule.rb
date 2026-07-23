# == Schema Information
#
# Table name: crm_automation_rules
#
#  id              :uuid             not null, primary key
#  actions         :jsonb            not null
#  active          :boolean          default(TRUE), not null
#  conditions      :jsonb            not null
#  name            :string           not null
#  trigger_type    :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  crm_pipeline_id :uuid
#
# Indexes
#
#  index_crm_automation_rules_on_account_id_and_active  (account_id,active)
#  index_crm_automation_rules_on_conditions             (conditions) USING gin
#  index_crm_automation_rules_on_crm_pipeline_id        (crm_pipeline_id)
#  index_crm_automation_rules_on_trigger_type           (trigger_type)
#
# Foreign Keys
#
#  fk_rails_...  (crm_pipeline_id => crm_pipelines.id)
#
class CrmAutomationRule < ApplicationRecord
  EVENT_TRIGGERS = %w[deal_created deal_entered_stage deal_stage_changed deal_updated deal_won deal_lost].freeze
  TIME_TRIGGERS = %w[deal_close_date_approaching deal_stagnant].freeze
  TRIGGER_TYPES = (EVENT_TRIGGERS + TIME_TRIGGERS).freeze

  belongs_to :account
  belongs_to :crm_pipeline, optional: true
  has_many :crm_automation_executions, dependent: :destroy

  validates :account_id, presence: true
  validates :name, presence: true
  validates :trigger_type, inclusion: { in: TRIGGER_TYPES }

  scope :active, -> { where(active: true) }
  scope :event_based, -> { where(trigger_type: EVENT_TRIGGERS) }
  scope :time_based, -> { where(trigger_type: TIME_TRIGGERS) }
end

CrmAutomationRule.prepend_mod_with('CrmAutomationRule')
