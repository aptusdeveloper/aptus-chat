require 'rails_helper'

RSpec.describe CrmAutomationRules::TriggerMatcher do
  let(:account) { create(:account) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:stage) { create(:crm_stage, account: account, crm_pipeline: pipeline) }
  let(:deal) { create(:crm_deal, account: account, crm_pipeline: pipeline, crm_stage: stage) }

  def matching_item(rule, trigger_types)
    described_class.matching_item(rule, trigger_types: trigger_types, deal: deal)
  end

  it 'matches a trigger without pipeline restriction' do
    rule = build(:crm_automation_rule, triggers: [{ 'trigger_type' => 'deal_created', 'crm_pipeline_id' => nil }])

    expect(matching_item(rule, ['deal_created'])[:trigger_type]).to eq('deal_created')
  end

  it 'does not match a trigger scoped to another pipeline' do
    other_pipeline = create(:crm_pipeline, account: account)
    rule = build(
      :crm_automation_rule,
      triggers: [{ 'trigger_type' => 'deal_created', 'crm_pipeline_id' => other_pipeline.id }]
    )

    expect(matching_item(rule, ['deal_created'])).to be_nil
  end

  it 'matches any selected stage for deal_entered_stage triggers' do
    other_stage = create(:crm_stage, account: account, crm_pipeline: pipeline)
    rule = build(
      :crm_automation_rule,
      triggers: [
        {
          'trigger_type' => 'deal_entered_stage',
          'crm_pipeline_id' => pipeline.id,
          'stage_ids' => [other_stage.id, stage.id]
        }
      ]
    )

    expect(matching_item(rule, ['deal_entered_stage'])[:stage_ids]).to include(stage.id)
  end

  it 'does not match deal_entered_stage when the stage is not selected' do
    other_stage = create(:crm_stage, account: account, crm_pipeline: pipeline)
    rule = build(
      :crm_automation_rule,
      triggers: [{ 'trigger_type' => 'deal_entered_stage', 'stage_ids' => [other_stage.id] }]
    )

    expect(matching_item(rule, ['deal_entered_stage'])).to be_nil
  end

  it 'returns the first repeated time trigger whose threshold is met' do
    deal.update!(stage_entered_at: 5.days.ago)
    rule = build(
      :crm_automation_rule,
      triggers: [
        { 'trigger_type' => 'deal_stagnant', 'days' => 10 },
        { 'trigger_type' => 'deal_stagnant', 'days' => 3 }
      ]
    )

    expect(matching_item(rule, ['deal_stagnant'])[:days]).to eq(3)
  end

  it 'matches close date approaching triggers by configured days' do
    deal.update!(close_date: 2.days.from_now.to_date)
    rule = build(
      :crm_automation_rule,
      triggers: [{ 'trigger_type' => 'deal_close_date_approaching', 'days' => 2 }]
    )

    expect(matching_item(rule, ['deal_close_date_approaching'])[:days]).to eq(2)
  end
end
