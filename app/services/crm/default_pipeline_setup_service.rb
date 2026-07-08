module Crm
  class DefaultPipelineSetupService
    DEFAULT_STAGES = [
      { name: 'Novo Lead',         color: '#3B82F6', position: 0, is_win: false, is_loss: false },
      { name: 'Qualificação Bot',  color: '#8B5CF6', position: 1, is_win: false, is_loss: false },
      { name: 'Aguardando Humano', color: '#F59E0B', position: 2, is_win: false, is_loss: false },
      { name: 'Em Atendimento',    color: '#06B6D4', position: 3, is_win: false, is_loss: false },
      { name: 'Ganho',             color: '#10B981', position: 4, is_win: true,  is_loss: false },
      { name: 'Perdido',           color: '#EF4444', position: 5, is_win: false, is_loss: true  }
    ].freeze

    def initialize(account)
      @account = account
    end

    def perform
      return if @account.crm_pipelines.exists?(is_default: true)

      ActiveRecord::Base.transaction do
        pipeline = @account.crm_pipelines.create!(
          name: 'Funil de Atendimento',
          active: true,
          position: 0,
          is_default: true
        )
        DEFAULT_STAGES.each do |attrs|
          pipeline.crm_stages.create!(attrs.merge(account: @account))
        end
        pipeline
      end
    end
  end
end
