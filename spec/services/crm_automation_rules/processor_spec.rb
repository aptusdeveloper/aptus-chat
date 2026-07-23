require 'rails_helper'

RSpec.describe CrmAutomationRules::Processor do
  let(:deal) { create(:crm_deal) }

  it 'processes deal_entered_stage rules' do
    rule = create(
      :crm_automation_rule,
      account: deal.account,
      crm_pipeline: deal.crm_pipeline,
      trigger_type: 'deal_entered_stage',
      conditions: [
        { attribute_key: 'crm_stage_id', filter_operator: 'equal_to', values: [deal.crm_stage_id] }
      ]
    )

    expect(CrmAutomationRules::ActionService).to receive(:new).with(rule, deal).and_call_original

    described_class.run(trigger_type: 'deal_entered_stage', deal: deal)
  end

  it 'does not process the same rule and deal inside the safety window' do
    rule = create(
      :crm_automation_rule,
      account: deal.account,
      crm_pipeline: deal.crm_pipeline,
      trigger_type: 'deal_entered_stage'
    )
    create(:crm_automation_execution, crm_automation_rule: rule, crm_deal: deal, executed_at: 1.minute.ago)

    expect(CrmAutomationRules::ActionService).not_to receive(:new)

    described_class.run(trigger_type: 'deal_entered_stage', deal: deal)
  end

  it 'allows retry when the recent execution failed' do
    rule = create(
      :crm_automation_rule,
      account: deal.account,
      crm_pipeline: deal.crm_pipeline,
      trigger_type: 'deal_entered_stage'
    )
    create(
      :crm_automation_execution,
      crm_automation_rule: rule,
      crm_deal: deal,
      status: 'failed',
      executed_at: 1.minute.ago
    )

    expect(CrmAutomationRules::ActionService).to receive(:new).with(rule, deal).and_call_original

    described_class.run(trigger_type: 'deal_entered_stage', deal: deal)
  end
end
