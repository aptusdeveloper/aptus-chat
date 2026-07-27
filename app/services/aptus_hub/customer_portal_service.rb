class AptusHub::CustomerPortalService
  class ConfigurationError < StandardError; end

  attr_reader :account, :user, :config

  def initialize(
    account:, user:, admin: false,
    botpress_client: AptusHub::BotpressClient.new,
    cost_calculator: nil
  )
    @account = account
    @user = user
    @admin = admin
    @botpress_client = botpress_client
    @config = AptusHub::AccountConfig.new(account)
    @cost_calculator = cost_calculator || AptusHub::PaymentCostCalculator.new(config: @config)
  end

  def performance(from:, to:)
    analytics = fetch_analytics(from, to)
    history = AptusHub::UsageHistoryBuilder.build(analytics[:records], analytics[:metrics])

    {
      bot: bot_payload,
      period: period_payload(from, to),
      metrics: admin ? analytics[:metrics] : analytics[:metrics].except(:llm_cost),
      channels: channels_payload,
      usage_history: admin ? history : history.map { |point| point.except(:llm_cost) }
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
    ensure_go_live_on!

    history = month_ids_from_go_live(today).map do |month|
      payment_history_item(month, today)
    end

    {
      plan: {
        monthly_fee: config.monthly_fee,
        currency: config.currency,
        payment_day: config.payment_day,
        go_live_on: config.go_live_on.strftime('%Y-%m-%d')
      },
      current_month: history.first,
      history: history
    }
  end

  def payment_details(month:, today: Time.zone.today)
    payment = config.payments.find { |item| item[:month] == month }
    metrics = resolve_metrics(month, payment, today)

    {
      month: month,
      status: payment_status(month, payment, today),
      due_on: due_date_for(month).strftime('%Y-%m-%d'),
      paid_at: payment&.dig(:paid_at),
      costs: cost_calculator.breakdown(month: month, metrics: metrics, payment: payment, today: today),
      metrics: metrics
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

  attr_reader :botpress_client, :cost_calculator, :admin

  def fetch_analytics(from, to)
    botpress_client.analytics(bot_id: config.bot_id, from: from, to: to)
  end

  # A closed month's metrics never change, so once frozen on the account they're read
  # from there for good; only the current (still-open) month is ever fetched live.
  def resolve_metrics(month, payment, today)
    return fetch_analytics(*month_range(month))[:metrics] if month == today.strftime('%Y-%m')
    return payment[:metrics] if payment&.dig(:metrics).present?

    fetch_analytics(*month_range(month))[:metrics].tap do |metrics|
      config.freeze_period_data!(month, metrics: metrics)
    end
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

  def ensure_go_live_on!
    return if config.go_live_on.present?

    raise ConfigurationError, 'Data de go-live do Hub Aptus nao configurada para esta conta.'
  end

  def month_ids_from_go_live(today)
    current_month = today.beginning_of_month
    first_month = config.go_live_on.beginning_of_month
    return [] if first_month > current_month

    months = []
    cursor = current_month
    while cursor >= first_month
      months << cursor.strftime('%Y-%m')
      cursor -= 1.month
    end
    months
  end

  def month_range(month)
    year, month_number = month.split('-').map(&:to_i)
    from = Date.new(year, month_number, 1)
    [from, from.end_of_month]
  end

  def payment_history_item(month, today)
    details = payment_details(month: month, today: today)

    {
      month: details[:month],
      status: details[:status],
      due_on: details[:due_on],
      paid_at: details[:paid_at],
      total: details.dig(:costs, :total),
      currency: details.dig(:costs, :currency)
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
