class Api::V1::Accounts::CrmPipelinesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_pipeline, only: [:show, :update, :destroy]

  def index
    @pipelines = Current.account.crm_pipelines.includes(:crm_stages).order(:position)
  end

  def show; end

  def create
    @pipeline = Current.account.crm_pipelines.build(pipeline_params)
    @pipeline.save!
  end

  def update
    @pipeline.update!(pipeline_params)
  end

  def destroy
    @pipeline.destroy!
    head :ok
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.crm_pipelines.find(params[:id])
  end

  def pipeline_params
    params.require(:crm_pipeline).permit(:name, :description, :active, :position)
  end
end
