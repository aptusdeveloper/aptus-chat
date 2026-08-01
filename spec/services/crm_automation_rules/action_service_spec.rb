require 'rails_helper'

RSpec.describe CrmAutomationRules::ActionService do
  let(:account) { create(:account) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:stage) { create(:crm_stage, account: account, crm_pipeline: pipeline) }
  let(:deal) { create(:crm_deal, account: account, crm_pipeline: pipeline, crm_stage: stage) }

  def perform_rule(actions)
    deal
    rule = create(:crm_automation_rule, account: account, actions: actions)
    described_class.new(rule, deal, trigger_type: rule.triggers.first['trigger_type']).perform
    rule
  end

  it 'moves a deal to another stage' do
    new_stage = create(:crm_stage, account: account, crm_pipeline: pipeline)

    perform_rule([{ action_name: 'change_stage', action_params: { stage_id: new_stage.id } }])

    expect(deal.reload.crm_stage).to eq(new_stage)
  end

  it 'assigns an agent' do
    agent = create(:user, account: account, role: :agent)

    perform_rule([{ action_name: 'assign_agent', action_params: { agent_id: agent.id } }])

    expect(deal.reload.assignee).to eq(agent)
  end

  it 'updates standard and custom fields' do
    perform_rule([
                   { action_name: 'update_field', action_params: { field: 'probability', value: 90 } },
                   { action_name: 'update_field', action_params: { field: 'custom_attributes.source', value: 'whatsapp' } }
                 ])

    expect(deal.reload.probability).to eq(90)
    expect(deal.custom_attributes['source']).to eq('whatsapp')
  end

  it 'enqueues webhook events' do
    expect(WebhookJob).to receive(:perform_later).with(
      'https://example.com/hook',
      hash_including(event: 'crm_automation_event', rule_id: kind_of(String))
    )

    perform_rule([{ action_name: 'send_webhook_event', action_params: { url: 'https://example.com/hook' } }])
  end

  it 'sends a text message to the latest linked conversation' do
    conversation = create(:conversation, account: account)
    create(:crm_deal_conversation, crm_deal: deal, conversation: conversation)

    perform_rule([
                   {
                     action_name: 'send_lead_message',
                     action_params: { content: 'Ola lead', content_type: 'text' }
                   }
                 ])

    message = conversation.messages.outgoing.last
    expect(message.content).to eq('Ola lead')
    expect(message.content_attributes['crm_deal_id']).to eq(deal.id)
  end

  it 'sends input_select messages' do
    conversation = create(:conversation, account: account)
    create(:crm_deal_conversation, crm_deal: deal, conversation: conversation)

    perform_rule([
                   {
                     action_name: 'send_lead_message',
                     action_params: {
                       content: 'Escolha uma opcao',
                       content_type: 'input_select',
                       content_attributes: {
                         items: [{ title: 'Tenho interesse', value: 'yes' }]
                       }
                     }
                   }
                 ])

    message = conversation.messages.outgoing.last
    expect(message.input_select?).to be(true)
    expect(message.items.first['title']).to eq('Tenho interesse')
  end

  it 'sends template params for WhatsApp and Twilio channels' do
    whatsapp_channel = create(
      :channel_whatsapp,
      account: account,
      validate_provider_config: false,
      sync_templates: false
    )
    inbox = whatsapp_channel.inbox
    conversation = create(:conversation, account: account, inbox: inbox)
    create(:crm_deal_conversation, crm_deal: deal, conversation: conversation)

    perform_rule([
                   {
                     action_name: 'send_lead_message',
                     action_params: {
                       content: 'Template aprovado',
                       template_params: { name: 'welcome', language: 'pt_BR', processed_params: {} }
                     }
                   }
                 ])

    message = conversation.messages.outgoing.last
    expect(message.additional_attributes['template_params']['name']).to eq('welcome')
  end

  it 'records rich message failures without stopping following actions' do
    email_channel = create(:channel_email, account: account)
    inbox = create(:inbox, account: account, channel: email_channel)
    conversation = create(:conversation, account: account, inbox: inbox)
    create(:crm_deal_conversation, crm_deal: deal, conversation: conversation)

    rule = perform_rule([
                          {
                            action_name: 'send_lead_message',
                            action_params: {
                              content: 'Template',
                              template_params: { name: 'welcome' }
                            }
                          },
                          { action_name: 'update_field', action_params: { field: 'probability', value: 80 } }
                        ])

    expect(deal.reload.probability).to eq(80)
    expect(rule.crm_automation_executions.failed.count).to eq(1)
  end
end
