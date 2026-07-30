require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::AgendaAppointmentsController', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:professional) { create(:agenda_professional, account: account) }
  let(:event_type) { create(:agenda_event_type, account: account, agenda_professional: professional, duration_minutes: 30) }
  let(:starts_at) { 1.day.from_now.change(hour: 9, min: 0) }
  let(:contact) { create(:contact, account: account, name: 'Maria') }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:stage) { create(:crm_stage, account: account, crm_pipeline: pipeline) }
  let(:deal) { create(:crm_deal, account: account, crm_pipeline: pipeline, crm_stage: stage, contact: contact, name: 'Tratamento Maria') }

  describe 'POST /api/v1/accounts/:account_id/agenda_appointments' do
    it 'creates a confirmed appointment' do
      post "/api/v1/accounts/#{account.id}/agenda_appointments",
           params: {
             agenda_professional_id: professional.id, agenda_event_type_id: event_type.id,
             starts_at: starts_at.iso8601, source: 'staff', patient_name: 'Maria',
             contact_id: contact.id, crm_deal_id: deal.id
           },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body['payload']
      expect(body['status']).to eq('confirmed')
      expect(body['patient_name']).to eq('Maria')
      expect(body['contact_id']).to eq(contact.id)
      expect(body['crm_deal_id']).to eq(deal.id)
      expect(body['contact']['name']).to eq('Maria')
      expect(body['crm_deal']['name']).to eq('Tratamento Maria')
    end

    it 'returns 422 when the slot is already taken' do
      create(:agenda_appointment, account: account, agenda_professional: professional, agenda_event_type: event_type,
                                  starts_at: starts_at, ends_at: starts_at + 30.minutes, status: 'confirmed')

      post "/api/v1/accounts/#{account.id}/agenda_appointments",
           params: { agenda_professional_id: professional.id, agenda_event_type_id: event_type.id, starts_at: starts_at.iso8601, source: 'staff' },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/agenda_appointments/:id' do
    let!(:appointment) do
      create(:agenda_appointment, account: account, agenda_professional: professional, agenda_event_type: event_type,
                                  starts_at: starts_at, ends_at: starts_at + 30.minutes, status: 'confirmed')
    end

    it 'updates contact and deal links' do
      patch "/api/v1/accounts/#{account.id}/agenda_appointments/#{appointment.id}",
            params: { contact_id: contact.id, crm_deal_id: deal.id },
            headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body['payload']
      expect(body['contact_id']).to eq(contact.id)
      expect(body['crm_deal_id']).to eq(deal.id)
      expect(appointment.reload.crm_deal).to eq(deal)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/agenda_appointments/:id/reschedule' do
    let!(:appointment) do
      create(:agenda_appointment, account: account, agenda_professional: professional, agenda_event_type: event_type,
                                  starts_at: starts_at, ends_at: starts_at + 30.minutes, status: 'confirmed')
    end

    it 'creates a new appointment and cancels the original' do
      new_starts_at = starts_at + 3.hours

      post "/api/v1/accounts/#{account.id}/agenda_appointments/#{appointment.id}/reschedule",
           params: { starts_at: new_starts_at.iso8601 }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']['id']).not_to eq(appointment.id)
      expect(appointment.reload.status).to eq('cancelled')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/agenda_appointments/:id/cancel' do
    let!(:appointment) do
      create(:agenda_appointment, account: account, agenda_professional: professional, agenda_event_type: event_type,
                                  starts_at: starts_at, ends_at: starts_at + 30.minutes, status: 'confirmed')
    end

    it 'cancels the appointment in place' do
      post "/api/v1/accounts/#{account.id}/agenda_appointments/#{appointment.id}/cancel",
           params: { reason: 'Paciente desistiu' }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']['status']).to eq('cancelled')
      expect(AgendaAppointment.count).to eq(1)
    end
  end
end
