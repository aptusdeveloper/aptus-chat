require 'rails_helper'

RSpec.describe CrmAutomationRules::ConditionsFilterService do
  let(:deal) do
    create(
      :crm_deal,
      amount: 1500,
      probability: 70,
      stage_entered_at: 3.days.ago,
      custom_attributes: { 'plan' => 'premium' }
    )
  end

  it 'matches standard deal fields' do
    rule = create(
      :crm_automation_rule,
      account: deal.account,
      conditions: [
        { attribute_key: 'amount', filter_operator: 'greater_than', values: [1000] }
      ]
    )

    expect(described_class.match?(rule, deal)).to be(true)
  end

  it 'matches deal custom attributes' do
    rule = create(
      :crm_automation_rule,
      account: deal.account,
      conditions: [
        { attribute_key: 'custom_attributes.plan', filter_operator: 'equal_to', values: ['premium'] }
      ]
    )

    expect(described_class.match?(rule, deal)).to be(true)
  end

  it 'matches days in stage' do
    deal.update_column(:stage_entered_at, 3.days.ago)
    rule = create(
      :crm_automation_rule,
      account: deal.account,
      conditions: [
        { attribute_key: 'days_in_stage', filter_operator: 'gte', values: [2] }
      ]
    )

    expect(described_class.match?(rule, deal)).to be(true)
  end
end
