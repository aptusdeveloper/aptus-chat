class CrmDealTimeCheckJob < ApplicationJob
  queue_as :low

  def perform
    Account.find_each do |account|
      process_account(account)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
    end
  end

  private

  def process_account(account)
    rules = CrmAutomationRule.active.time_based.where(account_id: account.id)
    return if rules.none?

    deals = CrmDeal.open.where(account_id: account.id)
    return if deals.none?

    rules.each do |rule|
      deals.each do |deal|
        process_rule_for_deal(rule, deal)
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: account).capture_exception
      end
    end
  end

  def process_rule_for_deal(rule, deal)
    matched_item = CrmAutomationRules::TriggerMatcher.matching_item(
      rule, trigger_types: CrmAutomationRule::TIME_TRIGGERS, deal: deal
    )
    return unless matched_item
    return if already_executed_today?(rule, deal)
    return unless CrmAutomationRules::ConditionsFilterService.match?(rule, deal)

    CrmAutomationRules::ActionService.new(rule, deal, trigger_type: matched_item['trigger_type']).perform
  end

  def already_executed_today?(rule, deal)
    CrmAutomationExecution.exists?(crm_automation_rule: rule,
                                   crm_deal: deal,
                                   executed_at: Time.current.all_day)
  end
end
