require 'rails_helper'

describe Agenda::SlotFinderService do
  subject(:slot_finder) do
    described_class.new(professional: professional, event_type: event_type, range_start: range_start, range_end: range_end)
  end

  let!(:account) { create(:account) }
  let!(:professional) { create(:agenda_professional, account: account, timezone: 'America/Sao_Paulo') }
  let(:test_date) { Date.new(2026, 8, 4) }
  let(:range_start) { ActiveSupport::TimeZone['America/Sao_Paulo'].local(test_date.year, test_date.month, test_date.day, 0, 0).utc }
  let(:range_end) { range_start + 1.day }
  let(:event_type) do
    create(:agenda_event_type, account: account, agenda_professional: professional, duration_minutes: 30, slot_interval_minutes: 30,
                               buffer_before_minutes: 0, buffer_after_minutes: 0, minimum_notice_minutes: 0)
  end

  def create_weekly_block(start_hour:, end_hour:, start_minutes: 0, end_minutes: 0)
    create(:agenda_availability, account: account, agenda_schedule: professional.agenda_schedule, day_of_week: test_date.wday,
                                 start_hour: start_hour, start_minutes: start_minutes, end_hour: end_hour, end_minutes: end_minutes)
  end

  describe '#call' do
    context 'with two blocks in the same day (morning and afternoon)' do
      before do
        create_weekly_block(start_hour: 8, end_hour: 12)
        create_weekly_block(start_hour: 14, end_hour: 18)
      end

      it 'returns slots from both blocks without bridging the gap between them' do
        slots = slot_finder.call
        starts = slots.map { |slot| slot.starts_at.in_time_zone('America/Sao_Paulo').strftime('%H:%M') }

        expect(starts.first).to eq('08:00')
        expect(starts).to include('11:30')
        expect(starts).to include('14:00')
        expect(starts).to include('17:30')
        expect(starts).not_to include('12:00')
        expect(starts).not_to include('13:30')
      end
    end

    context 'with a date override marking the day unavailable' do
      before do
        create_weekly_block(start_hour: 8, end_hour: 12)
        create(:agenda_availability, account: account, agenda_schedule: professional.agenda_schedule, day_of_week: nil, date: test_date,
                                     unavailable: true, start_hour: nil, start_minutes: nil, end_hour: nil, end_minutes: nil)
      end

      it 'returns no slots for that day, even though the weekly rule would normally allow it' do
        expect(slot_finder.call).to be_empty
      end
    end

    context 'with an existing appointment and a buffer after it' do
      before do
        create_weekly_block(start_hour: 8, end_hour: 12)
        busy_event_type = create(:agenda_event_type, account: account, agenda_professional: professional, duration_minutes: 30,
                                                     buffer_before_minutes: 0, buffer_after_minutes: 15)
        starts_at = ActiveSupport::TimeZone['America/Sao_Paulo'].local(test_date.year, test_date.month, test_date.day, 9, 0).utc
        create(:agenda_appointment, account: account, agenda_professional: professional, agenda_event_type: busy_event_type,
                                    starts_at: starts_at, ends_at: starts_at + 30.minutes, status: 'confirmed')
      end

      it 'pushes the next offered slot past the buffered window instead of right after the appointment ends' do
        slots = slot_finder.call
        starts = slots.map { |slot| slot.starts_at.in_time_zone('America/Sao_Paulo').strftime('%H:%M') }

        expect(starts).to include('08:00', '08:30')
        expect(starts).not_to include('09:00', '09:30')
        expect(starts).to include('10:00')
      end
    end

    context 'with a minimum notice period' do
      before do
        create_weekly_block(start_hour: 8, end_hour: 12)
        event_type.update!(minimum_notice_minutes: 150)
      end

      it 'excludes slots that fall before the minimum notice from now' do
        travel_to(range_start + 8.hours) do
          starts = slot_finder.call.map { |slot| slot.starts_at.in_time_zone('America/Sao_Paulo').strftime('%H:%M') }

          expect(starts).not_to include('08:00', '08:30', '09:00', '09:30')
          expect(starts).to include('10:30')
        end
      end
    end

    context 'when the availability block does not start on a slot-interval boundary' do
      before { create_weekly_block(start_hour: 8, start_minutes: 5, end_hour: 9) }

      it 'rounds the first offered slot up to the next interval boundary' do
        starts = slot_finder.call.map { |slot| slot.starts_at.in_time_zone('America/Sao_Paulo').strftime('%H:%M') }

        expect(starts.first).to eq('08:30')
        expect(starts).not_to include('08:05')
      end
    end
  end
end
