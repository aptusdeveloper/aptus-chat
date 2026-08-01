FactoryBot.define do
  factory :crm_pipeline do
    account
    sequence(:name) { |n| "Pipeline #{n}" }
    description { 'Sales pipeline' }
    active { true }
    position { 1.0 }
  end

  factory :crm_stage do
    crm_pipeline
    account { crm_pipeline.account }
    sequence(:name) { |n| "Stage #{n}" }
    color { '#6B7280' }
    position { 1.0 }
    is_win { false }
    is_loss { false }
  end

  factory :crm_deal do
    crm_pipeline
    account { crm_pipeline.account }
    crm_stage { association :crm_stage, crm_pipeline: crm_pipeline, account: account }
    sequence(:name) { |n| "Deal #{n}" }
    amount { 1000 }
    currency { 'BRL' }
    probability { 50 }
    custom_attributes { {} }
  end

  factory :crm_deal_conversation do
    crm_deal
    conversation
  end

  factory :crm_automation_rule do
    account
    sequence(:name) { |n| "CRM Automation #{n}" }
    triggers { [{ 'trigger_type' => 'deal_created', 'crm_pipeline_id' => nil, 'stage_ids' => [], 'days' => nil }] }
    conditions { [] }
    actions { [] }
    active { true }
  end

  factory :crm_automation_execution do
    crm_automation_rule
    crm_deal
    trigger_type { crm_automation_rule.triggers.first['trigger_type'] }
    status { 'success' }
    executed_at { Time.current }
  end
end
