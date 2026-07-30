require 'rails_helper'

describe Agenda::BookingService do
  let!(:account) { create(:account) }
  let!(:professional) { create(:agenda_professional, account: account) }
  let!(:event_type) { create(:agenda_event_type, account: account, agenda_professional: professional, duration_minutes: 30) }
  let(:starts_at) { 1.day.from_now.change(hour: 9, min: 0) }

  describe '.create!' do
    it 'creates a confirmed appointment with the computed end time' do
      appointment = described_class.create!(professional: professional, event_type: event_type, starts_at: starts_at, source: :bot)

      expect(appointment).to be_persisted
      expect(appointment).to be_confirmed
      expect(appointment.ends_at).to eq(starts_at + 30.minutes)
      expect(appointment.account_id).to eq(account.id)
    end

    it 'passes through optional patient attributes' do
      appointment = described_class.create!(
        professional: professional, event_type: event_type, starts_at: starts_at, source: :staff,
        attributes: { patient_name: 'Maria', patient_phone: '11999999999' }
      )

      expect(appointment.patient_name).to eq('Maria')
      expect(appointment.patient_phone).to eq('11999999999')
    end

    it 'raises SlotUnavailable when the slot overlaps an existing confirmed appointment' do
      create(:agenda_appointment, account: account, agenda_professional: professional, agenda_event_type: event_type,
                                  starts_at: starts_at, ends_at: starts_at + 30.minutes, status: 'confirmed')

      expect do
        described_class.create!(professional: professional, event_type: event_type, starts_at: starts_at, source: :bot)
      end.to raise_error(CustomExceptions::Agenda::SlotUnavailable)
    end

    it 'does not raise when the overlapping appointment is cancelled' do
      create(:agenda_appointment, account: account, agenda_professional: professional, agenda_event_type: event_type,
                                  starts_at: starts_at, ends_at: starts_at + 30.minutes, status: 'cancelled')

      expect do
        described_class.create!(professional: professional, event_type: event_type, starts_at: starts_at, source: :bot)
      end.not_to raise_error
    end
  end

  describe '.reschedule!' do
    let!(:appointment) do
      create(:agenda_appointment, account: account, agenda_professional: professional, agenda_event_type: event_type,
                                  starts_at: starts_at, ends_at: starts_at + 30.minutes, status: 'confirmed', patient_name: 'Maria')
    end
    let(:new_starts_at) { starts_at + 2.hours }

    it 'creates a new appointment linked to the original and cancels the original without deleting it' do
      new_appointment = described_class.reschedule!(appointment: appointment, new_starts_at: new_starts_at)

      expect(new_appointment).to be_persisted
      expect(new_appointment).to be_confirmed
      expect(new_appointment.starts_at).to eq(new_starts_at)
      expect(new_appointment.rescheduled_from_id).to eq(appointment.id)
      expect(new_appointment.patient_name).to eq('Maria')

      appointment.reload
      expect(appointment).to be_cancelled
      expect(appointment.rescheduled).to be(true)
    end

    it 'raises SlotUnavailable when the new time overlaps another confirmed appointment' do
      create(:agenda_appointment, account: account, agenda_professional: professional, agenda_event_type: event_type,
                                  starts_at: new_starts_at, ends_at: new_starts_at + 30.minutes, status: 'confirmed')

      expect do
        described_class.reschedule!(appointment: appointment, new_starts_at: new_starts_at)
      end.to raise_error(CustomExceptions::Agenda::SlotUnavailable)
    end
  end

  describe '.cancel!' do
    it 'updates the appointment status in place instead of creating a new record' do
      appointment = create(:agenda_appointment, account: account, agenda_professional: professional, agenda_event_type: event_type,
                                                starts_at: starts_at, ends_at: starts_at + 30.minutes, status: 'confirmed')

      expect { described_class.cancel!(appointment: appointment, reason: 'Paciente desistiu') }.not_to change(AgendaAppointment, :count)

      appointment.reload
      expect(appointment).to be_cancelled
      expect(appointment.cancellation_reason).to eq('Paciente desistiu')
    end
  end
end
