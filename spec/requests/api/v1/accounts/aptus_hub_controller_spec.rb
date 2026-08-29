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
      'go_live_on' => '2026-03-20',
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
    Redis::Alfred.scan_each(match: 'APTUS_HUB::*') { |key| Redis::Alfred.delete(key) }
    stub_botpress_bot
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

    it 'charges the go-live month pro rata, ignoring spend before go-live' do
      travel_to Time.zone.local(2026, 4, 5) do
        stub_botpress_analytics(records: [{ llm: { cost: { sum: 1.0 } } }], from: '2026-03-20', to: '2026-03-31')
        stub_exchange_rate(bid: '5.00')

        get "/api/v1/accounts/#{account.id}/hub/payments/2026-03", headers: headers
      end

      costs = response.parsed_body['costs']
      # go-live on the 20th of a 31-day month: 12 of 31 days billed.
      expect(costs['monthly_fee_billed_days']).to eq(12)
      expect(costs['monthly_fee']).to eq((299.9 * 12 / 31).round(2))
      expect(response.parsed_body['due_on']).to eq('2026-04-10')
    end

    it 'never counts anything before the go-live date' do
      stub_botpress_analytics(records: [], from: '2026-03-20', to: '2026-07-23')

      get "/api/v1/accounts/#{account.id}/hub/performance",
          headers: headers,
          params: { from: '2026-01-01', to: '2026-07-23' }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('period', 'from')).to eq('2026-03-20')
      expect(response.parsed_body.dig('bot', 'go_live_on')).to eq('2026-03-20')
    end

    it 'exposes WhatsApp plus only the client-facing integrations of the bot' do
      stub_botpress_analytics(records: [])

      get "/api/v1/accounts/#{account.id}/hub/performance",
          headers: headers,
          params: { from: '2026-07-01', to: '2026-07-23' }

      integrations = response.parsed_body['integrations']
      expect(integrations.pluck('name')).to eq(['WhatsApp', 'Kommo', 'Google Calendar'])
      expect(integrations.pluck('icon_url')).to eq(
        [
          '/assets/images/dashboard/hub/whatsapp.svg',
          '/assets/images/dashboard/hub/kommo.svg',
          'https://mediafiles.botpress.test/googlecalendar.svg'
        ]
      )
    end

    it 'returns a friendly error when Botpress fails' do
      stub_botpress_analytics(status: 500, records: [])

      get "/api/v1/accounts/#{account.id}/hub/performance",
          headers: headers,
          params: { from: '2026-07-01', to: '2026-07-23' }

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body['error']).to eq('Nao foi possivel buscar os dados do bot agora.')
    end

    it 'caches analytics for a short period to avoid duplicate calls for the same range' do
      stub_botpress_analytics(records: [{ sessions: 1 }])

      2.times do
        get "/api/v1/accounts/#{account.id}/hub/performance",
            headers: headers,
            params: { from: '2026-07-01', to: '2026-07-23' }
      end

      expect(response).to have_http_status(:success)
      expect(a_request(:get, %r{https://botpress\.test/admin/bots/bot-1/analytics})).to have_been_made.once
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

    it 'fetches Botpress analytics only once for an already-frozen past month' do
      travel_to Time.zone.local(2026, 7, 23) do
        stub_botpress_analytics(
          from: '2026-06-01', to: '2026-06-30',
          records: [{ sessions: 3, userMessages: 1, botMessages: 1, newUsers: 1, returningUsers: 0, events: 0,
                      llm: { cost: { sum: 2.0 } } }]
        )
        stub_exchange_rate(bid: '5.00')

        get "/api/v1/accounts/#{account.id}/hub/payments/2026-06", headers: headers
        get "/api/v1/accounts/#{account.id}/hub/payments/2026-06", headers: headers
      end

      expect(response).to have_http_status(:success)
      expect(a_request(:get, %r{https://botpress\.test/admin/bots/bot-1/analytics})).to have_been_made.once
      expect(a_request(:get, 'https://economia.awesomeapi.com.br/json/last/USD-BRL')).to have_been_made.once

      saved = account.reload.custom_attributes.dig('aptus_hub', 'payments').find { |item| item['month'] == '2026-06' }
      expect(saved.dig('metrics', 'sessions')).to eq(3)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/hub/payments' do
    it 'returns all months since the bot go-live with each month cost total' do
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
        expect(body.dig('plan', 'go_live_on')).to eq('2026-03-20')
        expect(body['history'].pluck('month')).to eq(%w[2026-07 2026-06 2026-05 2026-04 2026-03])
        expect(body.dig('current_month', 'month')).to eq('2026-07')
        # The running month has no closed amount yet, and is only due next month.
        expect(body.dig('current_month', 'status')).to eq('open')
        expect(body.dig('current_month', 'due_on')).to eq('2026-08-10')
        expect(body.dig('current_month', 'total')).to eq(current_month_total)
        expect(body['history'].second['month']).to eq('2026-06')
        expect(body['history'].second['status']).to eq('paid')
        expect(current_month_total).to be_present
        expect(past_month_total).to be_present
      end
    end

    it 'returns a clear configuration error when go-live is missing' do
      account.update!(custom_attributes: { 'aptus_hub' => hub_config.except('go_live_on') })

      get "/api/v1/accounts/#{account.id}/hub/payments", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('Data de go-live do Hub Aptus nao configurada para esta conta.')
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

  describe 'financial data restricted to administrators' do
    let(:agent) { create(:user, account: account, role: :agent) }
    let(:agent_headers) { agent.create_new_auth_token }

    it 'blocks an agent from the payments history' do
      get "/api/v1/accounts/#{account.id}/hub/payments", headers: agent_headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'blocks an agent from a month payment details' do
      get "/api/v1/accounts/#{account.id}/hub/payments/2026-06", headers: agent_headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'still allows performance for an agent, but without the llm_cost metric' do
      stub_botpress_analytics(
        records: [
          {
            sessions: 1, userMessages: 1, botMessages: 1, newUsers: 1, returningUsers: 0, events: 1,
            llm: { cost: { sum: 3.5 } }
          }
        ]
      )

      get "/api/v1/accounts/#{account.id}/hub/performance",
          headers: agent_headers,
          params: { from: '2026-07-01', to: '2026-07-23' }

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.dig('metrics', 'sessions')).to eq(1)
      expect(body['metrics']).not_to have_key('llm_cost')
      expect(body['usage_history'].first).not_to have_key('llm_cost')
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

  def stub_botpress_bot(status: 200)
    integrations = {
      'intver_1' => { 'name' => 'googlecalendar', 'title' => 'Google Calendar', 'enabled' => true,
                      'iconUrl' => 'https://mediafiles.botpress.test/googlecalendar.svg' },
      'intver_2' => { 'name' => 'aptus/kommo-izzy', 'title' => 'aptus/kommo-izzy', 'enabled' => true,
                      'iconUrl' => 'https://mediafiles.botpress.test/kommo.svg' },
      'intver_3' => { 'name' => 'openai', 'title' => 'OpenAI', 'enabled' => true,
                      'iconUrl' => 'https://mediafiles.botpress.test/openai.svg' },
      'intver_4' => { 'name' => 'aptus/kommo-bp', 'title' => 'aptus/kommo-bp', 'enabled' => false,
                      'iconUrl' => 'https://mediafiles.botpress.test/kommo-bp.svg' }
    }

    stub_request(:get, 'https://botpress.test/admin/bots/bot-1')
      .to_return(
        status: status,
        body: { bot: { integrations: integrations } }.to_json,
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
