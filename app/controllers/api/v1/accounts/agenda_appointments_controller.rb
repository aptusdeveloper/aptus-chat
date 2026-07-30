class Api::V1::Accounts::AgendaAppointmentsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_appointment, only: [:show, :update, :cancel, :reschedule]

  rescue_from CustomExceptions::Agenda::SlotUnavailable, with: :render_error_response

  def index
    @appointments = filtered_appointments.order(:starts_at)
  end

  def show; end

  def create
    professional = Current.account.agenda_professionals.find(params[:agenda_professional_id])
    event_type = Current.account.agenda_event_types.find(params[:agenda_event_type_id])

    @appointment = Agenda::BookingService.create!(
      professional: professional,
      event_type: event_type,
      starts_at: Time.iso8601(params[:starts_at]),
      source: params[:source] || :staff,
      attributes: appointment_attributes
    )
  end

  def update
    @appointment.update!(appointment_attributes)
  end

  def cancel
    Agenda::BookingService.cancel!(appointment: @appointment, reason: params[:reason])
    @appointment.reload
  end

  def reschedule
    @appointment = Agenda::BookingService.reschedule!(appointment: @appointment, new_starts_at: Time.iso8601(params[:starts_at]))
  end

  private

  def fetch_appointment
    @appointment = Current.account.agenda_appointments.find(params[:id])
  end

  def filtered_appointments
    appointments = Current.account.agenda_appointments
    appointments = appointments.where(agenda_professional_id: params[:agenda_professional_id]) if params[:agenda_professional_id].present?
    return appointments unless params[:date_from].present? && params[:date_to].present?

    appointments.where('starts_at < ? AND ends_at > ?', Time.iso8601(params[:date_to]), Time.iso8601(params[:date_from]))
  end

  def appointment_attributes
    params.permit(:contact_id, :conversation_id, :patient_name, :patient_phone, :notes).to_h.symbolize_keys
  end
end
