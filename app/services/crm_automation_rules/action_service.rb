class CrmAutomationRules::ActionService
  SUPPORTED_ACTIONS = %w[
    change_stage
    change_pipeline
    assign_agent
    update_field
    send_webhook_event
    send_lead_message
  ].freeze

  STANDARD_UPDATE_FIELDS = %w[
    name
    amount
    currency
    close_date
    probability
    assignee_id
    contact_id
    position
  ].freeze

  def initialize(rule, deal, trigger_type:)
    @rule, @deal, @trigger_type = rule, deal, trigger_type # rubocop:disable Style/ParallelAssignment
    @account = deal.account
  end

  def perform
    failures = []

    @rule.actions.each do |action|
      action = action.with_indifferent_access
      execute_action(action)
    rescue StandardError => e
      failures << e
      log_execution('failed', "#{failed_action_name(action)}: #{e.message}")
      ChatwootExceptionTracker.new(e, account: @account).capture_exception
    end

    log_execution('success') if failures.empty?
  end

  private

  def execute_action(action)
    action_name = action[:action_name].to_s
    raise ArgumentError, "Unsupported CRM automation action #{action_name}" unless SUPPORTED_ACTIONS.include?(action_name)

    send(action_name, action[:action_params])
  end

  def failed_action_name(action)
    return action[:action_name] if action.respond_to?(:key?) && action.key?(:action_name)

    'unknown_action'
  end

  def change_stage(params)
    stage = CrmStage.where(account_id: @account.id).find(param_value(params, :stage_id, 0))
    @deal.update!(crm_stage: stage, crm_pipeline: stage.crm_pipeline)
  end

  def change_pipeline(params)
    pipeline = @account.crm_pipelines.find(param_value(params, :pipeline_id, 0))
    first_stage = pipeline.crm_stages.ordered.first
    raise "Pipeline #{pipeline.id} has no stages" if first_stage.nil?

    @deal.update!(crm_pipeline: pipeline, crm_stage: first_stage)
  end

  def assign_agent(params)
    agent_id = param_value(params, :agent_id, 0) || param_value(params, :assignee_id, 0)
    agent = agent_id.present? ? @account.users.find(agent_id) : nil
    @deal.update!(assignee: agent)
  end

  def update_field(params)
    field = param_value(params, :field, 0).to_s
    value = param_value(params, :value, 1)
    raise ArgumentError, 'field is required' if field.blank?

    if field.start_with?('custom_attributes.')
      update_custom_attribute(field.delete_prefix('custom_attributes.'), value)
    elsif STANDARD_UPDATE_FIELDS.include?(field)
      @deal.update!(field => value)
    else
      update_custom_attribute(field, value)
    end
  end

  def send_webhook_event(params)
    url = param_value(params, :url, 0)
    raise ArgumentError, 'url is required' if url.blank?

    payload = {
      event: 'crm_automation_event',
      deal: @deal.as_json,
      rule_id: @rule.id
    }
    WebhookJob.perform_later(url, payload)
  end

  def send_lead_message(params)
    conversation = latest_linked_conversation
    raise ArgumentError, 'deal has no linked conversation' if conversation.blank?

    message_params = build_lead_message_params(params)
    ensure_rich_message_supported!(conversation, message_params)
    ensure_message_content_valid!(message_params)
    builder_params = ActionController::Parameters.new(message_params)
    Messages::MessageBuilder.new(nil, conversation, builder_params).perform
  end

  def update_custom_attribute(field, value)
    custom_attributes = (@deal.custom_attributes || {}).merge(field => value)
    @deal.update!(custom_attributes: custom_attributes)
  end

  def latest_linked_conversation
    @deal
      .conversations
      .where(account_id: @account.id)
      .reorder(last_activity_at: :desc, updated_at: :desc)
      .first
  end

  def build_lead_message_params(params)
    payload = normalized_params(params)
    content_attributes = normalized_hash(payload[:content_attributes] || payload[:metadata])
    content_attributes[:crm_automation_rule_id] = @rule.id
    content_attributes[:automation_rule_id] = @rule.id
    content_attributes[:crm_deal_id] = @deal.id

    {
      content: payload[:content],
      private: false,
      message_type: 'outgoing',
      content_type: payload[:content_type].presence || 'text',
      attachments: Array.wrap(payload[:attachments]).compact_blank,
      content_attributes: content_attributes,
      template_params: normalized_hash(payload[:template_params]).presence
    }.compact
  end

  def ensure_rich_message_supported!(conversation, message_params)
    inbox = conversation.inbox

    if message_params[:template_params].present? && !(inbox.whatsapp? || inbox.twilio?)
      raise ArgumentError, "templates are not supported for #{inbox.channel_type}"
    end

    return unless message_params[:content_type].to_s == 'input_select'
    return if inbox.whatsapp? || inbox.twilio_whatsapp? || inbox.web_widget? || inbox.api?

    raise ArgumentError, "input_select is not supported for #{inbox.channel_type}"
  end

  def ensure_message_content_valid!(message_params)
    return unless message_params[:content_type].to_s == 'input_select'

    items = Array.wrap(message_params.dig(:content_attributes, :items)).compact_blank
    raise ArgumentError, 'input_select requires at least one option' if items.blank?
  end

  def param_value(params, key, index = nil)
    payload = normalized_params(params)
    return payload[key] if payload.key?(key)
    return payload[key.to_s] if payload.key?(key.to_s)

    params[index] if params.is_a?(Array) && index
  end

  def normalized_params(params)
    case params
    when ActionController::Parameters
      params.to_unsafe_h.with_indifferent_access
    when Hash
      params.with_indifferent_access
    when Array
      return params.first.with_indifferent_access if params.first.is_a?(Hash)

      { values: params }.with_indifferent_access
    else
      {}.with_indifferent_access
    end
  end

  def normalized_hash(value)
    case value
    when ActionController::Parameters
      value.to_unsafe_h.with_indifferent_access
    when Hash
      value.with_indifferent_access
    when String
      JSON.parse(value).with_indifferent_access
    else
      {}.with_indifferent_access
    end
  rescue JSON::ParserError
    {}.with_indifferent_access
  end

  def log_execution(status, error_message = nil)
    CrmAutomationExecution.create!(
      crm_automation_rule: @rule,
      crm_deal: @deal,
      trigger_type: @trigger_type,
      status: status,
      executed_at: Time.current,
      error_message: error_message
    )
  end
end
