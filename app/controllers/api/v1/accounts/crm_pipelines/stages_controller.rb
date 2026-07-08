class Api::V1::Accounts::CrmPipelines::StagesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def check_authorization
    authorize(CrmStage)
  end
  before_action :fetch_pipeline
  before_action :fetch_stage, only: [:update, :destroy]

  def index
    @stages = @pipeline.crm_stages.order(:position)
  end

  def create
    @stage = @pipeline.crm_stages.build(stage_params.merge(account: Current.account))
    @stage.save!
  end

  def update
    @stage.update!(stage_params)
  end

  def destroy
    @stage.destroy!
    head :ok
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.crm_pipelines.find(params[:crm_pipeline_id])
  end

  def fetch_stage
    @stage = @pipeline.crm_stages.find(params[:id])
  end

  def stage_params
    params.require(:stage).permit(:name, :color, :position, :is_win, :is_loss)
  end
end
