require 'rails_helper'

RSpec.describe CrmAutomationRule, type: :model do
  let(:account) { create(:account) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:stage) { create(:crm_stage, account: account, crm_pipeline: pipeline) }

  it 'requires at least one trigger' do
    rule = build(:crm_automation_rule, account: account, triggers: [])

    expect(rule).not_to be_valid
    expect(rule.errors[:triggers]).to include('must have at least one trigger')
  end

  it 'requires triggers to be an array' do
    rule = build(:crm_automation_rule, account: account, triggers: 'deal_created')

    expect(rule).not_to be_valid
    expect(rule.errors[:triggers]).to include('must be an array')
  end

  it 'rejects malformed trigger items' do
    rule = build(:crm_automation_rule, account: account, triggers: ['deal_created'])

    expect(rule).not_to be_valid
    expect(rule.errors[:triggers]).to include('item 0: must be an object')
  end

  it 'validates trigger type' do
    rule = build(:crm_automation_rule, account: account, triggers: [{ 'trigger_type' => 'unknown' }])

    expect(rule).not_to be_valid
    expect(rule.errors[:triggers]).to include('item 0: invalid trigger_type "unknown"')
  end

  it 'requires stages for deal_entered_stage triggers' do
    rule = build(
      :crm_automation_rule,
      account: account,
      triggers: [{ 'trigger_type' => 'deal_entered_stage', 'stage_ids' => [] }]
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:triggers]).to include('item 0: deal_entered_stage requires at least one stage_id')
  end

  it 'requires positive days for time scoped triggers' do
    rule = build(
      :crm_automation_rule,
      account: account,
      triggers: [{ 'trigger_type' => 'deal_stagnant', 'days' => 0 }]
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:triggers]).to include('item 0: deal_stagnant requires days > 0')
  end

  it 'allows repeated trigger types with independent parameters' do
    other_stage = create(:crm_stage, account: account, crm_pipeline: pipeline)
    rule = build(
      :crm_automation_rule,
      account: account,
      triggers: [
        { 'trigger_type' => 'deal_entered_stage', 'crm_pipeline_id' => pipeline.id, 'stage_ids' => [stage.id] },
        { 'trigger_type' => 'deal_entered_stage', 'crm_pipeline_id' => pipeline.id, 'stage_ids' => [other_stage.id] }
      ]
    )

    expect(rule).to be_valid
  end

  it 'filters rules by trigger type' do
    created_rule = create(:crm_automation_rule, account: account, triggers: [{ 'trigger_type' => 'deal_created' }])
    create(:crm_automation_rule, account: account, triggers: [{ 'trigger_type' => 'deal_lost' }])

    expect(described_class.with_trigger_type('deal_created')).to contain_exactly(created_rule)
  end

  it 'groups event and time based rules by triggers jsonb' do
    event_rule = create(:crm_automation_rule, account: account, triggers: [{ 'trigger_type' => 'deal_updated' }])
    time_rule = create(:crm_automation_rule, account: account, triggers: [{ 'trigger_type' => 'deal_stagnant', 'days' => 2 }])

    expect(described_class.event_based).to include(event_rule)
    expect(described_class.event_based).not_to include(time_rule)
    expect(described_class.time_based).to include(time_rule)
    expect(described_class.time_based).not_to include(event_rule)
  end
end
