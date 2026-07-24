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

  describe 'GET /api/v1/accounts/:account_id/hub/performance' do
    it 'returns the linked bot performance for the current account' do
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

      get "/api/v1/accounts/#{account.id}/hub/performance",
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

      get "/api/v1/accounts/#{account.id}/hub/performance",
          headers: headers,
          params: { from: '2026-07-01', to: '2026-07-23' }

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body['error']).to eq('Nao foi possivel buscar os dados do bot agora.')
    end
  end

  describe 'GET /api/v1/accounts/:account_id/hub/payments/:month' do
    it 'uses a live exchange rate and returns the cost breakdown for the current month' do
      travel_to Time.zone.local(2026, 7, 23) do
        stub_botpress_analytics(
          from: '2026-07-01', to: '2026-07-31',
          records: [
            {
              sessions: 2, userMessages: 3, botMessages: 4, newUsers: 1, returningUsers: 1, events: 5,
              llm: { cost: { sum: 10.0 }, inputTokens: 100, outputTokens: 50, calls: 2, errors: 0 }
            }
          ]
        )
        stub_exchange_rate(bid: '5.00')

        get "/api/v1/accounts/#{account.id}/hub/payments/2026-07", headers: headers
      end

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      aggregate_failures do
        expect(body['month']).to eq('2026-07')
        expect(body.dig('costs', 'rate_is_live')).to be(true)
        expect(body.dig('costs', 'usd_brl_rate')).to eq(5.0)
        expect(body.dig('costs', 'llm_cost_usd')).to eq(10.0)
        expect(body.dig('costs', 'bot_fixed_cost_usd')).to eq(10.0)
        expect(body.dig('costs', 'api_cost_brl')).to eq(121.0)
        expect(body.dig('costs', 'total')).to eq(420.9)
        expect(body.dig('metrics', 'llm_tokens')).to eq(150)
      end
    end

    it 'does not persist the live exchange rate for the current month' do
      travel_to Time.zone.local(2026, 7, 23) do
        stub_botpress_analytics(from: '2026-07-01', to: '2026-07-31', records: [])
        stub_exchange_rate(bid: '5.00')

        get "/api/v1/accounts/#{account.id}/hub/payments/2026-07", headers: headers
      end

      persisted = account.reload.custom_attributes.dig('aptus_hub', 'payments')
      expect(persisted.find { |item| item['month'] == '2026-07' }).to be_nil
    end

    it 'freezes and persists the exchange rate for a past month without one saved yet' do
      travel_to Time.zone.local(2026, 7, 23) do
        stub_botpress_analytics(from: '2026-06-01', to: '2026-06-30', records: [])
        stub_exchange_rate(bid: '5.20')

        get "/api/v1/accounts/#{account.id}/hub/payments/2026-06", headers: headers
      end

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.dig('costs', 'rate_is_live')).to be(false)
      expect(body.dig('costs', 'usd_brl_rate')).to eq(5.2)
      expect(body['status']).to eq('paid')

      saved = account.reload.custom_attributes.dig('aptus_hub', 'payments').find { |item| item['month'] == '2026-06' }
      expect(saved['usd_brl_rate']).to eq(5.2)
    end

    it 'reuses an already frozen exchange rate for a past month' do
      account.update!(
        custom_attributes: {
          'aptus_hub' => hub_config.merge(
            'payments' => [{ 'month' => '2026-06', 'status' => 'paid', 'usd_brl_rate' => 4.5 }]
          )
        }
      )

      travel_to Time.zone.local(2026, 7, 23) do
        stub_botpress_analytics(from: '2026-06-01', to: '2026-06-30', records: [])

        get "/api/v1/accounts/#{account.id}/hub/payments/2026-06", headers: headers
      end

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.dig('costs', 'usd_brl_rate')).to eq(4.5)
      expect(body.dig('costs', 'rate_is_live')).to be(false)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/hub/payments' do
    it 'returns each month with its own cost total, not just the flat monthly fee' do
      travel_to Time.zone.local(2026, 7, 23) do
        stub_botpress_analytics_any(records: [{ llm: { cost: { sum: 4.0 } } }])
        stub_exchange_rate(bid: '5.00')

        get "/api/v1/accounts/#{account.id}/hub/payments", headers: headers
      end

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      current_month_total = body.dig('history', 0, 'total')
      past_month_total = body.dig('history', 1, 'total')

      aggregate_failures do
        expect(body.dig('plan', 'monthly_fee')).to eq(299.9)
        expect(body.dig('current_month', 'month')).to eq('2026-07')
        expect(body.dig('current_month', 'status')).to eq('overdue')
        expect(body.dig('current_month', 'total')).to eq(current_month_total)
        expect(body['history'].second['month']).to eq('2026-06')
        expect(body['history'].second['status']).to eq('paid')
        expect(current_month_total).to be_present
        expect(past_month_total).to be_present
      end
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

  def stub_botpress_analytics(records:, status: 200, from: '2026-07-01', to: '2026-07-23')
    stub_request(:get, 'https://botpress.test/admin/bots/bot-1/analytics')
      .with(
        query: {
          'startDate' => from,
          'endDate' => to
        }
      )
      .to_return(
        status: status,
        body: { records: records }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_botpress_analytics_any(records: [], status: 200)
    stub_request(:get, %r{https://botpress\.test/admin/bots/bot-1/analytics})
      .to_return(
        status: status,
        body: { records: records }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_exchange_rate(bid:, status: 200)
    stub_request(:get, 'https://economia.awesomeapi.com.br/json/last/USD-BRL')
      .to_return(
        status: status,
        body: { USDBRL: { bid: bid } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end
