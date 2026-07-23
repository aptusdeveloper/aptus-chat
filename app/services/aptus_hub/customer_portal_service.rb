class AptusHub::CustomerPortalService
  DEFAULT_HISTORY_MONTHS = 6

  attr_reader :account, :user, :config

  def initialize(account:, user:, botpress_client: AptusHub::BotpressClient.new)
    @account = account
    @user = user
    @botpress_client = botpress_client
    @config = AptusHub::AccountConfig.new(account)
  end

  def overview(from:, to:)
    analytics = fetch_analytics(from, to)

    {
      bot: bot_payload,
      period: period_payload(from, to),
      metrics: analytics[:metrics],
      channels: channels_payload
    }
  end

  def performance(from:, to:)
    analytics = fetch_analytics(from, to)

    {
      bot: bot_payload,
      period: period_payload(from, to),
      metrics: analytics[:metrics],
      usage_history: usage_history(analytics[:records], analytics[:metrics])
    }
  end

  def webchat_config
    script_url = config.webchat_script_url

    {
      script_url: script_url,
      configured: script_url.present?
    }
  end

  def payments(today: Time.zone.today)
    history = month_ids(today, DEFAULT_HISTORY_MONTHS).map do |month|
      payment_history_item(month, today)
    end

    {
      plan: {
        monthly_fee: config.monthly_fee,
        currency: config.currency,
        payment_day: config.payment_day
      },
      current_month: history.first,
      history: history
    }
  end

  def create_feedback!(conversation_id:, comment:)
    payload = {
      'conversation_id' => conversation_id,
      'bot_id' => config.bot_id,
      'comment' => comment,
      'user' => {
        'id' => user.id,
        'name' => user.name,
        'email' => user.email
      },
      'created_at' => Time.current.iso8601
    }

    config.append_feedback!(payload)
    { success: true }
  end

  private

  attr_reader :botpress_client

  def fetch_analytics(from, to)
    botpress_client.analytics(bot_id: config.bot_id, from: from, to: to)
  end

  def bot_payload
    {
      id: config.bot_id,
      name: config.bot_name,
      status: config.status,
      ai_model: config.ai_model
    }
  end

  def period_payload(from, to)
    {
      from: from.strftime('%Y-%m-%d'),
      to: to.strftime('%Y-%m-%d')
    }
  end

  def channels_payload
    account.inboxes.order(:name).map do |inbox|
      {
        id: inbox.id,
        name: inbox.name,
        channel_type: inbox.channel_type,
        status: 'connected'
      }
    end
  end

  def usage_history(records, fallback_metrics)
    points = records.each_with_index.map do |record, index|
      usage_history_point(record.with_indifferent_access, index)
    end

    points.presence || [fallback_usage_history_point(fallback_metrics)]
  end

  def usage_history_point(record, index)
    {
      label: record_label(record, index),
      sessions: record[:sessions].to_i,
      user_messages: record[:userMessages].to_i,
      bot_messages: record[:botMessages].to_i,
      total_messages: record[:userMessages].to_i + record[:botMessages].to_i,
      total_users: record[:newUsers].to_i + record[:returningUsers].to_i
    }
  end

  def fallback_usage_history_point(metrics)
    {
      label: 'Periodo',
      sessions: metrics[:sessions],
      user_messages: metrics[:user_messages],
      bot_messages: metrics[:bot_messages],
      total_messages: metrics[:total_messages],
      total_users: metrics[:total_users]
    }
  end

  def record_label(record, index)
    date_value =
      record[:date].presence ||
      record[:startDate].presence ||
      record[:endDate].presence
    return "P#{index + 1}" if date_value.blank?

    Date.iso8601(date_value.to_s[0, 10]).strftime('%d/%m')
  rescue ArgumentError
    "P#{index + 1}"
  end

  def month_ids(today, count)
    current_month = today.beginning_of_month
    Array.new(count) { |offset| (current_month - offset.months).strftime('%Y-%m') }
  end

  def payment_history_item(month, today)
    payment = config.payments.find { |item| item[:month] == month }

    {
      month: month,
      status: payment_status(month, payment, today),
      due_on: due_date_for(month).strftime('%Y-%m-%d'),
      paid_at: payment&.dig(:paid_at)
    }
  end

  def payment_status(month, payment, today)
    return 'paid' if payment&.dig(:status) == 'paid'

    due_date_for(month) < today ? 'overdue' : 'pending'
  end

  def due_date_for(month)
    year, month_number = month.split('-').map(&:to_i)
    last_day = Date.new(year, month_number, 1).end_of_month.day
    Date.new(year, month_number, [config.payment_day, last_day].min)
  end
end
