class Api::V1::Accounts::AgendaProfessionals::AvailabilitiesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_professional
  before_action :fetch_availability, only: [:update, :destroy]

  def index
    @availabilities = @professional.agenda_schedule.agenda_availabilities.order(:day_of_week, :date, :start_hour)
  end

  def create
    @availability = @professional.agenda_schedule.agenda_availabilities.build(availability_params.merge(account_id: Current.account.id))
    @availability.save!
  end

  def update
    @availability.update!(availability_params)
  end

  def destroy
    @availability.destroy!
    head :ok
  end

  private

  def fetch_professional
    @professional = Current.account.agenda_professionals.find(params[:agenda_professional_id])
  end

  def fetch_availability
    @availability = @professional.agenda_schedule.agenda_availabilities.find(params[:id])
  end

  def availability_params
    params.require(:agenda_availability).permit(:day_of_week, :date, :start_hour, :start_minutes, :end_hour, :end_minutes, :unavailable)
  end
end
