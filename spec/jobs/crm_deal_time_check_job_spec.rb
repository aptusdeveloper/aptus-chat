require 'rails_helper'

RSpec.describe CrmDealTimeCheckJob do
  it 'respects the automation pipeline for time based rules' do
    account = create(:account)
    matching_pipeline = create(:crm_pipeline, account: account)
    other_pipeline = create(:crm_pipeline, account: account)
    other_stage = create(:crm_stage, account: account, crm_pipeline: other_pipeline)
    deal = create(:crm_deal, account: account, crm_pipeline: other_pipeline, crm_stage: other_stage, stage_entered_at: 4.days.ago)

    rule = create(
      :crm_automation_rule,
      account: account,
      triggers: [{ 'trigger_type' => 'deal_stagnant', 'crm_pipeline_id' => matching_pipeline.id, 'stage_ids' => [], 'days' => 1 }],
      conditions: [],
      actions: [{ action_name: 'update_field', action_params: { field: 'probability', value: 10 } }]
    )

    described_class.perform_now

    expect(deal.reload.probability).not_to eq(10)
    expect(rule.crm_automation_executions).to be_empty
  end
end
