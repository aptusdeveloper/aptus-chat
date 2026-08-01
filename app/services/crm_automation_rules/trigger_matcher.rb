class CrmAutomationRules::TriggerMatcher
  def self.matching_item(rule, trigger_types:, deal:)
    new(rule, deal).matching_item(trigger_types)
  end

  def initialize(rule, deal)
    @rule = rule
    @deal = deal
  end

  def matching_item(trigger_types)
    Array(@rule.triggers).map(&:with_indifferent_access).find do |item|
      trigger_types.include?(item[:trigger_type]) && item_matches?(item)
    end
  end

  private

  def item_matches?(item)
    return false unless pipeline_matches?(item)
    return false if item[:trigger_type] == 'deal_entered_stage' && !stage_matches?(item)
    return false if CrmAutomationRule::DAYS_SCOPED_TRIGGERS.include?(item[:trigger_type]) && !days_threshold_met?(item)

    true
  end

  def pipeline_matches?(item)
    item[:crm_pipeline_id].blank? || item[:crm_pipeline_id] == @deal.crm_pipeline_id
  end

  def stage_matches?(item)
    Array(item[:stage_ids]).include?(@deal.crm_stage_id)
  end

  def days_threshold_met?(item)
    threshold = item[:days].to_i
    return false if threshold <= 0

    case item[:trigger_type]
    when 'deal_stagnant'
      days_in_stage >= threshold
    when 'deal_close_date_approaching'
      @deal.close_date.present? && @deal.close_date.to_date == threshold.days.from_now.to_date
    end
  end

  def days_in_stage
    return 0 if @deal.stage_entered_at.blank?

    ((Time.current - @deal.stage_entered_at) / 86_400).to_i
  end
end
