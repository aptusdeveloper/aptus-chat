class CrmAutomationRules::ConditionsFilterService
  OPERATORS = {
    'equal_to' => ->(val, target) { val == target },
    'not_equal_to' => ->(val, target) { val != target },
    'greater_than' => ->(val, target) { val.present? && val > target },
    'less_than' => ->(val, target) { val.present? && val < target },
    'gte' => ->(val, target) { val.present? && val >= target },
    'lte' => ->(val, target) { val.present? && val <= target },
    'contains' => ->(val, target) { val.to_s.include?(target.to_s) },
    'starts_with' => ->(val, target) { val.to_s.start_with?(target.to_s) },
    'is_present' => ->(val, _target) { val.present? },
    'is_not_present' => ->(val, _target) { val.blank? },
    'days_before' => ->(val, target) { val.present? && val.to_date == target.to_i.days.from_now.to_date },
    'is_today' => ->(val, _target) { val.present? && val.to_date == Date.current },
    'is_past' => ->(val, _target) { val.present? && val.to_date < Date.current },
    'is_future' => ->(val, _target) { val.present? && val.to_date > Date.current }
  }.freeze

  def self.match?(rule, deal)
    new(rule, deal).match?
  end

  def initialize(rule, deal)
    @rule = rule
    @deal = deal
  end

  def match?
    return true if @rule.conditions.blank?

    results = @rule.conditions.map { |condition| evaluate_condition(condition.with_indifferent_access) }
    combine_results(results)
  rescue StandardError => e
    Rails.logger.error "CrmAutomationRules::ConditionsFilterService error for rule #{@rule.id}: #{e.message}"
    false
  end

  private

  def evaluate_condition(condition)
    attribute_key = condition[:attribute_key]
    operator      = condition[:filter_operator]
    values        = condition[:values]
    target        = values.is_a?(Array) ? values.first : values

    value = resolve_attribute(attribute_key)
    op_fn = OPERATORS[operator]
    return false if op_fn.nil?

    op_fn.call(value, target)
  end

  def resolve_attribute(key)
    return days_in_stage if key == 'days_in_stage'

    @deal.public_send(key)
  rescue NoMethodError
    nil
  end

  def days_in_stage
    return 0 if @deal.stage_entered_at.blank?

    ((Time.current - @deal.stage_entered_at) / 86_400).to_i
  end

  def combine_results(results)
    @rule.conditions.each_with_index.reduce(nil) do |acc, (condition, idx)|
      current = results[idx]
      query_op = condition.with_indifferent_access[:query_operator]

      next current if acc.nil?

      case query_op&.upcase
      when 'OR'  then acc || current
      else            acc && current
      end
    end
  end
end
