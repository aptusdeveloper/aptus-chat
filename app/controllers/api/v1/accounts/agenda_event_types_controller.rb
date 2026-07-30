class Api::V1::Accounts::AgendaEventTypesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_event_type, only: [:show, :update, :destroy]

  def index
    @event_types = Current.account.agenda_event_types.order(:name)
  end

  def show; end

  def create
    @event_type = Current.account.agenda_event_types.build(event_type_params)
    @event_type.save!
  end

  def update
    @event_type.update!(event_type_params)
  end

  def destroy
    @event_type.destroy!
    head :ok
  end

  private

  def fetch_event_type
    @event_type = Current.account.agenda_event_types.find(params[:id])
  end

  def event_type_params
    params.require(:agenda_event_type).permit(
      :agenda_professional_id, :name, :duration_minutes, :buffer_before_minutes, :buffer_after_minutes,
      :minimum_notice_minutes, :slot_interval_minutes, :active, :description, :color
    )
  end
end
