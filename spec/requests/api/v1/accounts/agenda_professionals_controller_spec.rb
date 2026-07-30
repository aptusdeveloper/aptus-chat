require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::AgendaProfessionalsController', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/:account_id/agenda_professionals' do
    it 'returns the professionals for the account' do
      professional = create(:agenda_professional, account: account)

      get "/api/v1/accounts/#{account.id}/agenda_professionals", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].first['id']).to eq(professional.id)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/agenda_professionals' do
    let(:payload) { { agenda_professional: { name: 'Dra. Bárbarah', specialty: 'Estética', timezone: 'America/Sao_Paulo' } } }

    it 'creates a professional (and its default schedule) for administrators' do
      post "/api/v1/accounts/#{account.id}/agenda_professionals", params: payload, headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      professional = AgendaProfessional.find(response.parsed_body['payload']['id'])
      expect(professional.name).to eq('Dra. Bárbarah')
      expect(professional.agenda_schedule).to be_present
    end

    it 'blocks agents from creating a professional' do
      post "/api/v1/accounts/#{account.id}/agenda_professionals", params: payload, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/agenda_professionals/:id/available_slots' do
    let!(:professional) { create(:agenda_professional, account: account, timezone: 'America/Sao_Paulo') }
    let!(:event_type) { create(:agenda_event_type, account: account, duration_minutes: 30, slot_interval_minutes: 30) }
    let(:tuesday) { Date.new(2026, 8, 4) }

    before do
      create(:agenda_availability, account: account, agenda_schedule: professional.agenda_schedule, day_of_week: tuesday.wday,
                                   start_hour: 8, end_hour: 12)
    end

    it 'returns the free slots computed from the weekly availability' do
      range_start = ActiveSupport::TimeZone['America/Sao_Paulo'].local(tuesday.year, tuesday.month, tuesday.day, 0, 0)
      range_end = range_start + 1.day

      get "/api/v1/accounts/#{account.id}/agenda_professionals/#{professional.id}/available_slots",
          params: { event_type_id: event_type.id, date_from: range_start.iso8601, date_to: range_end.iso8601 },
          headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      slots = response.parsed_body['slots']
      first_slot_local = Time.iso8601(slots.first['start']).in_time_zone('America/Sao_Paulo')
      expect(first_slot_local.strftime('%H:%M')).to eq('08:00')
    end
  end

  describe 'nested availabilities' do
    let!(:professional) { create(:agenda_professional, account: account) }

    it 'lets administrators configure the weekly schedule' do
      payload = { agenda_availability: { day_of_week: 2, start_hour: 8, start_minutes: 0, end_hour: 12, end_minutes: 0 } }

      post "/api/v1/accounts/#{account.id}/agenda_professionals/#{professional.id}/availabilities",
           params: payload, headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(professional.agenda_schedule.agenda_availabilities.count).to eq(1)
    end

    it 'blocks agents from configuring the weekly schedule' do
      payload = { agenda_availability: { day_of_week: 2, start_hour: 8, start_minutes: 0, end_hour: 12, end_minutes: 0 } }

      post "/api/v1/accounts/#{account.id}/agenda_professionals/#{professional.id}/availabilities",
           params: payload, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
