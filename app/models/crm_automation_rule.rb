# == Schema Information
#
# Table name: crm_automation_rules
#
#  id         :uuid             not null, primary key
#  actions    :jsonb            not null
#  active     :boolean          default(TRUE), not null
#  conditions :jsonb            not null
#  name       :string           not null
#  triggers   :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_crm_automation_rules_on_account_id_and_active  (account_id,active)
#  index_crm_automation_rules_on_conditions             (conditions) USING gin
#  index_crm_automation_rules_on_triggers               (triggers) USING gin
#
class CrmAutomationRule < ApplicationRecord
  EVENT_TRIGGERS = %w[deal_created deal_entered_stage deal_stage_changed deal_updated deal_won deal_lost].freeze
  TIME_TRIGGERS = %w[deal_close_date_approaching deal_stagnant].freeze
  TRIGGER_TYPES = (EVENT_TRIGGERS + TIME_TRIGGERS).freeze
  DAYS_SCOPED_TRIGGERS = %w[deal_stagnant deal_close_date_approaching].freeze

  belongs_to :account
  has_many :crm_automation_executions, dependent: :destroy

  validates :account_id, presence: true
  validates :name, presence: true
  validate :triggers_shape

  scope :active, -> { where(active: true) }
  scope :with_trigger_type, ->(trigger_type) { where('triggers @> ?', [{ trigger_type: trigger_type }].to_json) }
  scope :event_based, -> { EVENT_TRIGGERS.reduce(none) { |scope, type| scope.or(with_trigger_type(type)) } }
  scope :time_based, -> { TIME_TRIGGERS.reduce(none) { |scope, type| scope.or(with_trigger_type(type)) } }

  private

  def triggers_shape
    unless triggers.is_a?(Array)
      errors.add(:triggers, 'must be an array')
      return
    end

    if triggers.blank?
      errors.add(:triggers, 'must have at least one trigger')
      return
    end

    triggers.each_with_index do |item, index|
      unless item.respond_to?(:with_indifferent_access)
        errors.add(:triggers, "item #{index}: must be an object")
        next
      end

      validate_trigger_item(item.with_indifferent_access, index)
    end
  end

  def validate_trigger_item(item, index)
    type = item[:trigger_type]
    unless TRIGGER_TYPES.include?(type)
      errors.add(:triggers, "item #{index}: invalid trigger_type #{type.inspect}")
      return
    end

    if type == 'deal_entered_stage' && Array(item[:stage_ids]).compact_blank.empty?
      errors.add(:triggers, "item #{index}: deal_entered_stage requires at least one stage_id")
    end

    return unless DAYS_SCOPED_TRIGGERS.include?(type) && item[:days].to_i <= 0

    errors.add(:triggers, "item #{index}: #{type} requires days > 0")
  end
end

CrmAutomationRule.prepend_mod_with('CrmAutomationRule')
