require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::CrmAutomationRulesController', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:stage) { create(:crm_stage, account: account, crm_pipeline: pipeline) }

  let(:payload) do
    {
      crm_automation_rule: {
        name: 'Boas-vindas na qualificacao',
        active: true,
        triggers: [
          {
            trigger_type: 'deal_entered_stage',
            crm_pipeline_id: pipeline.id,
            stage_ids: [stage.id]
          },
          {
            trigger_type: 'deal_stagnant',
            crm_pipeline_id: nil,
            days: 3
          }
        ],
        conditions: [],
        actions: [
          {
            action_name: 'send_lead_message',
            action_params: {
              content: 'Ola! Recebemos seu contato.',
              content_type: 'text',
              attachments: []
            }
          }
        ]
      }
    }
  end

  describe 'GET /api/v1/accounts/:account_id/crm_automation_rules' do
    it 'returns CRM automation rules for administrators' do
      rule = create(
        :crm_automation_rule, account: account,
                              triggers: [{ 'trigger_type' => 'deal_created', 'crm_pipeline_id' => pipeline.id, 'stage_ids' => [], 'days' => nil }]
      )

      get "/api/v1/accounts/#{account.id}/crm_automation_rules",
          headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      response_rule = body['payload'].first
      expect(response_rule['id']).to eq(rule.id)
      expect(response_rule).not_to have_key('trigger_type')
      expect(response_rule).not_to have_key('crm_pipeline_id')
      expect(response_rule['triggers'].first['crm_pipeline_name']).to eq(pipeline.name)
    end

    it 'blocks agents' do
      get "/api/v1/accounts/#{account.id}/crm_automation_rules",
          headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm_automation_rules' do
    it 'creates a CRM automation rule' do
      expect do
        post "/api/v1/accounts/#{account.id}/crm_automation_rules",
             headers: administrator.create_new_auth_token,
             params: payload
      end.to change(CrmAutomationRule, :count).by(1)

      expect(response).to have_http_status(:success)
      rule = CrmAutomationRule.last
      expect(rule.name).to eq('Boas-vindas na qualificacao')
      expect(rule.triggers.first['trigger_type']).to eq('deal_entered_stage')
      expect(rule.triggers.second['days']).to eq(3)
      expect(rule.actions.first['action_name']).to eq('send_lead_message')
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/crm_automation_rules/:id' do
    it 'updates partial attributes' do
      rule = create(:crm_automation_rule, account: account, active: true)

      patch "/api/v1/accounts/#{account.id}/crm_automation_rules/#{rule.id}",
            headers: administrator.create_new_auth_token,
            params: { crm_automation_rule: { active: false } }

      expect(response).to have_http_status(:success)
      expect(rule.reload.active).to be(false)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm_automation_rules/:id/clone' do
    it 'duplicates the rule as inactive' do
      rule = create(:crm_automation_rule, account: account, active: true)

      expect do
        post "/api/v1/accounts/#{account.id}/crm_automation_rules/#{rule.id}/clone",
             headers: administrator.create_new_auth_token
      end.to change(CrmAutomationRule, :count).by(1)

      expect(response).to have_http_status(:success)
      cloned_rule = CrmAutomationRule.find(response.parsed_body.dig('payload', 'id'))
      expect(cloned_rule.active).to be(false)
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/crm_automation_rules/:id' do
    it 'deletes the rule' do
      rule = create(:crm_automation_rule, account: account)

      expect do
        delete "/api/v1/accounts/#{account.id}/crm_automation_rules/#{rule.id}",
               headers: administrator.create_new_auth_token
      end.to change(CrmAutomationRule, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
