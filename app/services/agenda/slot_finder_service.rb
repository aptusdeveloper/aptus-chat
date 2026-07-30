class Agenda::SlotFinderService
  Slot = Struct.new(:starts_at, :ends_at)

  def initialize(professional:, event_type:, range_start:, range_end:)
    @professional = professional
    @event_type = event_type
    @range_start = range_start.utc
    @range_end = range_end.utc
  end

  def call
    slots_from(subtract(availability_ranges, busy_ranges))
  end

  private

  attr_reader :professional, :event_type, :range_start, :range_end

  def availability_ranges
    schedule = professional.agenda_schedule
    return [] unless schedule

    ranges = (range_start.to_date..range_end.to_date).flat_map { |date| ranges_for_date(schedule, date) }
    merge(ranges.sort_by(&:begin))
  end

  def ranges_for_date(schedule, date)
    overrides = schedule.agenda_availabilities.date_overrides.where(date: date)
    if overrides.any?
      return [] if overrides.any?(&:unavailable?)

      return overrides.filter_map { |override| range_for(date, override) }
    end

    schedule.agenda_availabilities.weekly.where(day_of_week: date.wday).filter_map { |availability| range_for(date, availability) }
  end

  def range_for(date, availability)
    zone = ActiveSupport::TimeZone[professional.timezone] || Time.zone
    starts_at = zone.local(date.year, date.month, date.day, availability.start_hour, availability.start_minutes).utc
    ends_at = zone.local(date.year, date.month, date.day, availability.end_hour, availability.end_minutes).utc
    clamp(starts_at..ends_at)
  end

  def clamp(range)
    clamped_start = [range.begin, range_start].max
    clamped_end = [range.end, range_end].min
    return nil if clamped_start >= clamped_end

    clamped_start..clamped_end
  end

  def busy_ranges
    appointments = professional.agenda_appointments.active.includes(:agenda_event_type)
                               .where('starts_at < ? AND ends_at > ?', range_end, range_start)

    ranges = appointments.map do |appointment|
      before_buffer = appointment.agenda_event_type.buffer_before_minutes.minutes
      after_buffer = appointment.agenda_event_type.buffer_after_minutes.minutes
      (appointment.starts_at - before_buffer)..(appointment.ends_at + after_buffer)
    end
    merge(ranges.sort_by(&:begin))
  end

  def merge(ranges)
    ranges.each_with_object([]) do |range, merged|
      last = merged.last
      if last && range.begin <= last.end
        merged[-1] = last.begin..[last.end, range.end].max
      else
        merged << range
      end
    end
  end

  def subtract(base_ranges, busy_ranges)
    base_ranges.flat_map { |base| subtract_from_range(base, busy_ranges) }
  end

  def subtract_from_range(range, busy_ranges)
    busy_ranges.reduce([range]) { |remaining, busy| remaining.flat_map { |piece| split(piece, busy) } }
  end

  def split(range, busy)
    return [range] if busy.end <= range.begin || busy.begin >= range.end

    pieces = []
    pieces << (range.begin..busy.begin) if busy.begin > range.begin
    pieces << (busy.end..range.end) if busy.end < range.end
    pieces
  end

  def slots_from(free_ranges)
    duration = event_type.duration_minutes.minutes
    step = event_type.slot_interval_minutes.minutes
    earliest = round_up(Time.current.utc + event_type.minimum_notice_minutes.minutes, event_type.slot_interval_minutes)

    free_ranges.flat_map { |range| slots_in_range(range, duration, step, earliest) }
  end

  def slots_in_range(range, duration, step, earliest)
    cursor = [round_up(range.begin, event_type.slot_interval_minutes), earliest].max
    slots = []
    while cursor + duration <= range.end
      slots << Slot.new(cursor, cursor + duration)
      cursor += step
    end
    slots
  end

  def round_up(time, minutes)
    return time if minutes.zero?

    interval = minutes * 60
    remainder = time.to_i % interval
    return time if remainder.zero?

    Time.at(time.to_i + (interval - remainder)).utc
  end
end
