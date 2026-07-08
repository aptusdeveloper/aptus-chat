module CrmDealEventBroadcaster
  def self.broadcast(deal, previous_changes)
    return if previous_changes.blank?

    triggers = detect_triggers(deal, previous_changes)
    triggers.each do |trigger_type|
      CrmAutomationRules::Processor.run(trigger_type: trigger_type, deal: deal)
    end
  end

  def self.detect_triggers(deal, previous_changes)
    triggers = []

    if previous_changes.key?('id')
      triggers << 'deal_created'
      return triggers
    end

    triggers << 'deal_updated'

    if previous_changes.key?('crm_stage_id')
      triggers << 'deal_stage_changed'
      triggers << 'deal_won' if deal.crm_stage.is_win
      triggers << 'deal_lost' if deal.crm_stage.is_loss
    end

    triggers
  end
  private_class_method :detect_triggers
end
