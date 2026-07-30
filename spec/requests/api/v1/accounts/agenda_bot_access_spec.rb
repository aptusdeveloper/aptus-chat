require 'rails_helper'

RSpec.describe 'Agenda endpoints — Agent Bot access', type: :request do
  let(:account) { create(:account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:bot_headers) { { api_access_token: agent_bot.access_token.token } }
  let(:professional) { create(:agenda_professional, account: account, timezone: 'America/Sao_Paulo') }
  let(:event_type) do
    create(:agenda_event_type, account: account, agenda_professional: professional, duration_minutes: 30, slot_interval_minutes: 30)
  end
  let(:tuesday) { Date.new(2026, 8, 4) }

  before do
    create(:agenda_availability, account: account, agenda_schedule: professional.agenda_schedule, day_of_week: tuesday.wday,
                                 start_hour: 8, end_hour: 12)
  end

  describe 'available_slots (whitelisted)' do
    it 'allows a bot to check availability' do
      range_start = ActiveSupport::TimeZone['America/Sao_Paulo'].local(tuesday.year, tuesday.month, tuesday.day, 0, 0)

      get "/api/v1/accounts/#{account.id}/agenda_professionals/#{professional.id}/available_slots",
          params: { event_type_id: event_type.id, date_from: range_start.iso8601, date_to: (range_start + 1.day).iso8601 },
          headers: bot_headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['slots']).not_to be_empty
    end
  end

  describe 'appointments (whitelisted)' do
    it 'allows a bot to create, reschedule and cancel an appointment' do
      starts_at = ActiveSupport::TimeZone['America/Sao_Paulo'].local(tuesday.year, tuesday.month, tuesday.day, 9, 0)

      post "/api/v1/accounts/#{account.id}/agenda_appointments",
           params: {
             agenda_professional_id: professional.id, agenda_event_type_id: event_type.id,
             starts_at: starts_at.iso8601, source: 'bot'
           }, headers: bot_headers

      expect(response).to have_http_status(:success)
      appointment_id = response.parsed_body['payload']['id']

      post "/api/v1/accounts/#{account.id}/agenda_appointments/#{appointment_id}/reschedule",
           params: { starts_at: (starts_at + 2.hours).iso8601 }, headers: bot_headers
      expect(response).to have_http_status(:success)
      rescheduled_id = response.parsed_body['payload']['id']

      post "/api/v1/accounts/#{account.id}/agenda_appointments/#{rescheduled_id}/cancel",
           params: { reason: 'Bot test' }, headers: bot_headers
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']['status']).to eq('cancelled')
    end
  end

  describe 'agenda_professionals create (NOT whitelisted for bots)' do
    it 'blocks a bot from creating a professional' do
      post "/api/v1/accounts/#{account.id}/agenda_professionals",
           params: { agenda_professional: { name: 'Dra. Teste', timezone: 'America/Sao_Paulo' } }, headers: bot_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'availabilities (NOT whitelisted for bots at all)' do
    it 'blocks a bot from configuring the weekly schedule' do
      get "/api/v1/accounts/#{account.id}/agenda_professionals/#{professional.id}/availabilities", headers: bot_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
