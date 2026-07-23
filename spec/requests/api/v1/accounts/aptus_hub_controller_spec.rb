require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::AptusHubController', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:headers) { administrator.create_new_auth_token }
  let(:hub_config) do
    {
      'enabled' => true,
      'bot_id' => 'bot-1',
      'bot_name' => 'Bot Aptus',
      'monthly_fee' => 299.9,
      'currency' => 'BRL',
      'payment_day' => 10,
      'payments' => [
        { 'month' => '2026-06', 'status' => 'paid', 'paid_at' => '2026-06-09T12:00:00Z' }
      ]
    }
  end

  around do |example|
    with_modified_env BOTPRESS_API_URL: 'https://botpress.test',
                      BOTPRESS_API_KEY: 'secret',
                      BOTPRESS_WORKSPACE_ID: 'workspace-1' do
      example.run
    end
  end

  before do
    account.update!(custom_attributes: { 'aptus_hub' => hub_config })
  end

  describe 'GET /api/v1/accounts/:account_id/hub/overview' do
    it 'returns the linked bot overview for the current account' do
      stub_botpress_analytics(
        records: [
          {
            sessions: 2,
            userMessages: 3,
            botMessages: 4,
            newUsers: 1,
            returningUsers: 1,
            events: 5,
            llm: { cost: { sum: 0.12 } }
          }
        ]
      )

      get "/api/v1/accounts/#{account.id}/hub/overview",
          headers: headers,
          params: { from: '2026-07-01', to: '2026-07-23' }

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.dig('bot', 'id')).to eq('bot-1')
      expect(body.dig('bot', 'name')).to eq('Bot Aptus')
      expect(body.dig('metrics', 'sessions')).to eq(2)
      expect(body.dig('metrics', 'total_messages')).to eq(7)
      expect(body.dig('metrics', 'total_users')).to eq(2)
    end

    it 'returns a friendly error when Botpress fails' do
      stub_botpress_analytics(status: 500, records: [])

      get "/api/v1/accounts/#{account.id}/hub/overview",
          headers: headers,
          params: { from: '2026-07-01', to: '2026-07-23' }

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body['error']).to eq('Nao foi possivel buscar os dados do bot agora.')
    end
  end

  describe 'GET /api/v1/accounts/:account_id/hub/payments' do
    it 'returns readonly payment status for the latest months' do
      travel_to Time.zone.local(2026, 7, 23) do
        get "/api/v1/accounts/#{account.id}/hub/payments", headers: headers
      end

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.dig('plan', 'monthly_fee')).to eq(299.9)
      expect(body.dig('current_month', 'month')).to eq('2026-07')
      expect(body.dig('current_month', 'status')).to eq('overdue')
      expect(body['history'].second['month']).to eq('2026-06')
      expect(body['history'].second['status']).to eq('paid')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/hub/feedback' do
    it 'stores feedback with the linked bot and current user' do
      post "/api/v1/accounts/#{account.id}/hub/feedback",
           headers: headers,
           params: {
             conversationId: 'conv-1',
             comentario: 'Resposta confusa no teste',
             bot_id: 'other-bot'
           }

      expect(response).to have_http_status(:success)

      feedback = account.reload.custom_attributes.dig('aptus_hub', 'feedback').last
      expect(feedback['conversation_id']).to eq('conv-1')
      expect(feedback['comment']).to eq('Resposta confusa no teste')
      expect(feedback['bot_id']).to eq('bot-1')
      expect(feedback.dig('user', 'id')).to eq(administrator.id)
    end
  end

  describe 'access control' do
    it 'blocks accounts with Hub disabled' do
      account.update!(custom_attributes: { 'aptus_hub' => hub_config.merge('enabled' => false) })

      get "/api/v1/accounts/#{account.id}/hub/payments", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'blocks accounts without a linked bot' do
      account.update!(custom_attributes: { 'aptus_hub' => hub_config.merge('bot_id' => nil) })

      get "/api/v1/accounts/#{account.id}/hub/payments", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'prevents cross-account access' do
      other_account = create(:account)
      other_user = create(:user, account: other_account, role: :administrator)

      get "/api/v1/accounts/#{account.id}/hub/payments",
          headers: other_user.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end
  end

  def stub_botpress_analytics(records:, status: 200)
    stub_request(:get, 'https://botpress.test/admin/bots/bot-1/analytics')
      .with(
        query: {
          'startDate' => '2026-07-01',
          'endDate' => '2026-07-23'
        }
      )
      .to_return(
        status: status,
        body: { records: records }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end
