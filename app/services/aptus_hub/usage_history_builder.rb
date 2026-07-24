class AptusHub::UsageHistoryBuilder
  def self.build(records, fallback_metrics)
    new(records, fallback_metrics).build
  end

  def initialize(records, fallback_metrics)
    @records = records
    @fallback_metrics = fallback_metrics
  end

  def build
    points = records.map { |record| point_for(record.with_indifferent_access) }
    points.presence || [fallback_point]
  end

  private

  attr_reader :records, :fallback_metrics

  def point_for(record)
    {
      date: date_for(record),
      bucket_start: bucket_start_for(record),
      sessions: record[:sessions].to_i,
      user_messages: record[:userMessages].to_i,
      bot_messages: record[:botMessages].to_i,
      total_messages: record[:userMessages].to_i + record[:botMessages].to_i,
      total_users: record[:newUsers].to_i + record[:returningUsers].to_i,
      llm_cost: record.dig(:llm, :cost, :sum).to_f
    }
  end

  def fallback_point
    {
      date: nil,
      bucket_start: nil,
      sessions: fallback_metrics[:sessions],
      user_messages: fallback_metrics[:user_messages],
      bot_messages: fallback_metrics[:bot_messages],
      total_messages: fallback_metrics[:total_messages],
      total_users: fallback_metrics[:total_users],
      llm_cost: fallback_metrics[:llm_cost]
    }
  end

  def date_for(record)
    value = record[:startDateTimeUtc].presence || record[:endDateTimeUtc].presence
    return nil if value.blank?

    Date.iso8601(value.to_s[0, 10]).strftime('%Y-%m-%d')
  rescue ArgumentError
    nil
  end

  # Botpress buckets by hour instead of by day when the requested range is
  # narrow (e.g. "today"). Kept separate from `date` (always day-granularity)
  # so the frontend can tell the two cases apart and label points accordingly.
  def bucket_start_for(record)
    value = record[:startDateTimeUtc].presence || record[:endDateTimeUtc].presence
    return nil if value.blank?

    Time.iso8601(value.to_s)
    value.to_s
  rescue ArgumentError
    nil
  end
end
