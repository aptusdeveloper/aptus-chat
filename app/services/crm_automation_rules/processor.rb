class CrmAutomationRules::Processor
  def self.run(trigger_type:, deal:)
    new(trigger_type: trigger_type, deal: deal).run
  end

  def self.recently_executed?(rule, deal)
    CrmAutomationExecution.successful.where(
      crm_automation_rule: rule,
      crm_deal: deal
    ).exists?(['executed_at >= ?', deal.updated_at])
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
    CrmAutomationRule.active.where(account_id: @account.id).with_trigger_type(@trigger_type)
  end

  def process_rule(rule)
    matched_item = CrmAutomationRules::TriggerMatcher.matching_item(rule, trigger_types: [@trigger_type], deal: @deal)
    return unless matched_item
    return if self.class.recently_executed?(rule, @deal)
    return unless CrmAutomationRules::ConditionsFilterService.match?(rule, @deal)

    CrmAutomationRules::ActionService.new(rule, @deal, trigger_type: @trigger_type).perform
  end
end
