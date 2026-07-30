class Api::V1::Accounts::AgendaProfessionalsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_professional, only: [:show, :update, :destroy, :available_slots]

  def index
    @professionals = Current.account.agenda_professionals.order(:name)
  end

  def show; end

  def create
    @professional = Current.account.agenda_professionals.build(professional_params)
    @professional.save!
  end

  def update
    @professional.update!(professional_params)
  end

  def destroy
    @professional.destroy!
    head :ok
  end

  def available_slots
    event_type = Current.account.agenda_event_types.find(params[:event_type_id])
    slots = Agenda::SlotFinderService.new(
      professional: @professional,
      event_type: event_type,
      range_start: Time.iso8601(params[:date_from]),
      range_end: Time.iso8601(params[:date_to])
    ).call

    render json: { slots: slots.map { |slot| { start: slot.starts_at.iso8601, end: slot.ends_at.iso8601 } } }
  end

  private

  def fetch_professional
    @professional = Current.account.agenda_professionals.find(params[:id])
  end

  def professional_params
    params.require(:agenda_professional).permit(:name, :specialty, :timezone, :active, :color, :user_id)
  end
end
