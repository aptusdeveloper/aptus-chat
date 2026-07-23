class CrmAutomationRules::Processor
  IDEMPOTENCY_WINDOW = 5.minutes

  def self.run(trigger_type:, deal:)
    new(trigger_type: trigger_type, deal: deal).run
  end

  def self.recently_executed?(rule, deal, since: IDEMPOTENCY_WINDOW.ago)
    CrmAutomationExecution.successful.where(
      crm_automation_rule: rule,
      crm_deal: deal,
      executed_at: since..Time.current
    ).exists?
  end

  def initialize(trigger_type:, deal:)
    @trigger_type = trigger_type
    @deal         = deal
    @account      = deal.account
  end

  def run
    rules.each do |rule|
      process_rule(rule)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: @account).capture_exception
    end
  end

  private

  def rules
    scope = CrmAutomationRule.active.where(trigger_type: @trigger_type, account_id: @account.id)
    scope.select { |rule| rule.crm_pipeline_id.nil? || rule.crm_pipeline_id == @deal.crm_pipeline_id }
  end

  def process_rule(rule)
    return if self.class.recently_executed?(rule, @deal)
    return unless CrmAutomationRules::ConditionsFilterService.match?(rule, @deal)

    CrmAutomationRules::ActionService.new(rule, @deal).perform
  end
end
