class CrmAutomationRules::ActionService
  def initialize(rule, deal)
    @rule    = rule
    @deal    = deal
    @account = deal.account
  end

  def perform
    @rule.actions.each do |action|
      action = action.with_indifferent_access
      send(action[:action_name], action[:action_params])
    end
    log_execution('success')
  rescue StandardError => e
    log_execution('failed', e.message)
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
  end

  private

  def change_stage(params)
    stage = @account.crm_stages.find(params[0])
    @deal.update!(crm_stage: stage, crm_pipeline: stage.crm_pipeline)
  end

  def change_pipeline(params)
    pipeline = @account.crm_pipelines.find(params[0])
    first_stage = pipeline.crm_stages.ordered.first
    raise "Pipeline #{pipeline.id} has no stages" if first_stage.nil?

    @deal.update!(crm_pipeline: pipeline, crm_stage: first_stage)
  end

  def assign_agent(params)
    agent = @account.users.find_by(id: params[0])
    @deal.update!(assignee: agent)
  end

  def update_field(params)
    field = params[0][:field] || params[0]['field']
    value = params[0][:value] || params[0]['value']
    @deal.update!(field => value)
  end

  def send_webhook_event(params)
    payload = { event: 'crm_automation_event', deal: @deal.as_json, rule_id: @rule.id }
    WebhookJob.perform_later(params[0], payload)
  end

  def send_email_to_assignee(_params)
    Rails.logger.info "CrmAutomationRules: send_email_to_assignee called for deal #{@deal.id} — not implemented"
  end

  def add_note(_params)
    Rails.logger.info "CrmAutomationRules: add_note called for deal #{@deal.id} — not implemented"
  end

  def log_execution(status, error_message = nil)
    CrmAutomationExecution.create!(
      crm_automation_rule: @rule,
      crm_deal: @deal,
      trigger_type: @rule.trigger_type,
      status: status,
      executed_at: Time.current,
      error_message: error_message
    )
  end
end
