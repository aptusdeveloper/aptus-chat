class AptusHub::BotpressClient
  class Error < StandardError; end

  ANALYTICS_FIELD_MAP = {
    sessions: :sessions,
    user_messages: :userMessages,
    bot_messages: :botMessages,
    new_users: :newUsers,
    returning_users: :returningUsers,
    events: :events
  }.freeze

  def analytics(bot_id:, from:, to:)
    response = HTTParty.get(
      "#{api_url}/admin/bots/#{CGI.escape(bot_id)}/analytics",
      query: {
        startDate: from.strftime('%Y-%m-%d'),
        endDate: to.strftime('%Y-%m-%d')
      },
      headers: headers,
      timeout: 30
    )

    raise Error, 'Nao foi possivel buscar os dados do bot agora.' unless response.success?

    parse_analytics_response(response)
  rescue Error
    raise
  rescue StandardError => e
    Rails.logger.error "[AptusHub] Botpress analytics failed for #{bot_id}: #{e.message}"
    raise Error, 'Nao foi possivel buscar os dados do bot agora.'
  end

  private

  def api_url
    value = ENV.fetch('BOTPRESS_API_URL', '').delete_suffix('/')
    raise Error, 'Botpress ainda nao esta configurado.' if value.blank?

    value
  end

  def api_key
    ENV.fetch('BOTPRESS_API_KEY', '').presence ||
      raise(Error, 'Botpress ainda nao esta configurado.')
  end

  def workspace_id
    ENV.fetch('BOTPRESS_WORKSPACE_ID', '').presence ||
      raise(Error, 'Botpress ainda nao esta configurado.')
  end

  def headers
    {
      'Authorization' => "Bearer #{api_key}",
      'x-workspace-id' => workspace_id,
      'Accept' => 'application/json'
    }
  end

  def parse_analytics_response(response)
    body = response.parsed_response
    body = JSON.parse(response.body) if body.is_a?(String)
    records = Array.wrap(body['records'])

    {
      metrics: aggregate_records(records),
      records: records
    }
  rescue JSON::ParserError => e
    Rails.logger.error "[AptusHub] Invalid Botpress analytics response: #{e.message}"
    raise Error, 'Nao foi possivel ler os dados do bot agora.'
  end

  def aggregate_records(records)
    totals = empty_metrics
    records.each do |record|
      add_record_metrics(totals, record.with_indifferent_access)
    end

    totals[:total_users] = totals[:new_users] + totals[:returning_users]
    totals[:total_messages] = totals[:user_messages] + totals[:bot_messages]
    totals[:llm_tokens] = totals[:llm_input_tokens] + totals[:llm_output_tokens]
    totals
  end

  def add_record_metrics(totals, record)
    ANALYTICS_FIELD_MAP.each do |metric_key, record_key|
      totals[metric_key] += record[record_key].to_i
    end
    totals[:llm_cost] += record.dig(:llm, :cost, :sum).to_f
    totals[:llm_input_tokens] += record.dig(:llm, :inputTokens).to_i
    totals[:llm_output_tokens] += record.dig(:llm, :outputTokens).to_i
    totals[:llm_calls] += record.dig(:llm, :calls).to_i
    totals[:llm_errors] += record.dig(:llm, :errors).to_i
  end

  def empty_metrics
    {
      sessions: 0,
      user_messages: 0,
      bot_messages: 0,
      total_messages: 0,
      new_users: 0,
      returning_users: 0,
      total_users: 0,
      events: 0,
      llm_cost: 0.0,
      llm_input_tokens: 0,
      llm_output_tokens: 0,
      llm_tokens: 0,
      llm_calls: 0,
      llm_errors: 0
    }
  end
end
