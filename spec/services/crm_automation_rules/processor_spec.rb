require 'rails_helper'

RSpec.describe CrmAutomationRules::Processor do
  let(:deal) { create(:crm_deal) }
  let(:stage_trigger) do
    [
      {
        'trigger_type' => 'deal_entered_stage',
        'crm_pipeline_id' => deal.crm_pipeline_id,
        'stage_ids' => [deal.crm_stage_id],
        'days' => nil
      }
    ]
  end

  it 'processes deal_entered_stage rules' do
    rule = create(
      :crm_automation_rule,
      account: deal.account,
      triggers: stage_trigger,
      conditions: [
        { attribute_key: 'crm_stage_id', filter_operator: 'equal_to', values: [deal.crm_stage_id] }
      ]
    )

    expect(CrmAutomationRules::ActionService)
      .to receive(:new)
      .with(rule, deal, trigger_type: 'deal_entered_stage')
      .and_call_original

    described_class.run(trigger_type: 'deal_entered_stage', deal: deal)
  end

  it 'does not reprocess the same rule and deal when it already succeeded for the current deal state' do
    rule = create(
      :crm_automation_rule,
      account: deal.account,
      triggers: stage_trigger
    )
    create(:crm_automation_execution, crm_automation_rule: rule, crm_deal: deal, executed_at: Time.current)

    expect(CrmAutomationRules::ActionService).not_to receive(:new)

    described_class.run(trigger_type: 'deal_entered_stage', deal: deal)
  end

  it 'reprocesses the same rule and deal once the deal changes again after a successful execution' do
    rule = create(
      :crm_automation_rule,
      account: deal.account,
      triggers: stage_trigger
    )
    create(:crm_automation_execution, crm_automation_rule: rule, crm_deal: deal, executed_at: Time.current)
    deal.update!(name: 'Updated deal name')

    expect(CrmAutomationRules::ActionService)
      .to receive(:new)
      .with(rule, deal, trigger_type: 'deal_entered_stage')
      .and_call_original

    described_class.run(trigger_type: 'deal_entered_stage', deal: deal)
  end

  it 'allows retry when the recent execution failed' do
    rule = create(
      :crm_automation_rule,
      account: deal.account,
      triggers: stage_trigger
    )
    create(
      :crm_automation_execution,
      crm_automation_rule: rule,
      crm_deal: deal,
      status: 'failed',
      executed_at: 1.minute.ago
    )

    expect(CrmAutomationRules::ActionService)
      .to receive(:new)
      .with(rule, deal, trigger_type: 'deal_entered_stage')
      .and_call_original

    described_class.run(trigger_type: 'deal_entered_stage', deal: deal)
  end
end
