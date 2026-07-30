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

  def bulk_replace_weekly
    schedule = @professional.agenda_schedule
    ActiveRecord::Base.transaction do
      schedule.agenda_availabilities.weekly.destroy_all
      weekly_blocks_params.each do |block_params|
        schedule.agenda_availabilities.create!(block_params.merge(account_id: Current.account.id))
      end
    end
    @availabilities = schedule.agenda_availabilities.order(:day_of_week, :date, :start_hour)
    render :index
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

  def weekly_blocks_params
    params.require(:agenda_availabilities).map do |block_params|
      ActionController::Parameters.new(block_params).permit(:day_of_week, :start_hour, :start_minutes, :end_hour, :end_minutes)
    end
  end
end
