class Agenda::BookingService
  APPOINTMENT_ATTRIBUTE_KEYS = %i[contact_id conversation_id patient_name patient_phone notes].freeze

  def self.create!(professional:, event_type:, starts_at:, source:, attributes: {})
    ends_at = starts_at + event_type.duration_minutes.minutes

    AgendaAppointment.transaction do
      ensure_slot_available!(professional, event_type, starts_at, ends_at)

      AgendaAppointment.create!(
        attributes.slice(*APPOINTMENT_ATTRIBUTE_KEYS).merge(
          account_id: professional.account_id,
          agenda_professional: professional,
          agenda_event_type: event_type,
          starts_at: starts_at,
          ends_at: ends_at,
          status: :confirmed,
          source: source
        )
      )
    end
  end

  def self.reschedule!(appointment:, new_starts_at:)
    event_type = appointment.agenda_event_type
    new_ends_at = new_starts_at + event_type.duration_minutes.minutes

    AgendaAppointment.transaction do
      ensure_slot_available!(appointment.agenda_professional, event_type, new_starts_at, new_ends_at, exclude_appointment_id: appointment.id)

      new_appointment = AgendaAppointment.create!(
        copied_attributes(appointment).merge(starts_at: new_starts_at, ends_at: new_ends_at, rescheduled_from: appointment)
      )
      appointment.update!(status: :cancelled, rescheduled: true, cancelled_at: Time.current)
      new_appointment
    end
  end

  def self.cancel!(appointment:, reason: nil)
    appointment.update!(status: :cancelled, cancelled_at: Time.current, cancellation_reason: reason)
  end

  def self.copied_attributes(appointment)
    {
      account_id: appointment.account_id,
      agenda_professional: appointment.agenda_professional,
      agenda_event_type: appointment.agenda_event_type,
      contact_id: appointment.contact_id,
      conversation_id: appointment.conversation_id,
      patient_name: appointment.patient_name,
      patient_phone: appointment.patient_phone,
      notes: appointment.notes,
      status: :confirmed,
      source: appointment.source
    }
  end

  def self.ensure_slot_available!(professional, event_type, starts_at, ends_at, exclude_appointment_id: nil)
    buffer_before = event_type.buffer_before_minutes.minutes
    buffer_after = event_type.buffer_after_minutes.minutes

    conflicts = professional.agenda_appointments.active
                            .where('starts_at < ? AND ends_at > ?', ends_at + buffer_after, starts_at - buffer_before)
    conflicts = conflicts.where.not(id: exclude_appointment_id) if exclude_appointment_id

    raise CustomExceptions::Agenda::SlotUnavailable.new({}) if conflicts.exists?
  end

  private_class_method :copied_attributes, :ensure_slot_available!
end
