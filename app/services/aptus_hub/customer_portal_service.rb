class AptusHub::CustomerPortalService
  class ConfigurationError < StandardError; end

  # WhatsApp is the channel every bot answers on, so the client always sees it here
  # even though it reaches the bot through this inbox rather than through a Botpress
  # integration of its own.
  WHATSAPP_INTEGRATION = {
    name: 'WhatsApp',
    icon_url: '/assets/images/dashboard/hub/whatsapp.svg'
  }.freeze

  # A bot carries a dozen Botpress integrations the client has no reason to see
  # (LLM providers, chart/PDF helpers). Only the ones they recognize as their own
  # tooling are surfaced, in this order, under a name they actually use.
  #
  # Each client gets their own private Kommo build (kommo-izzy, ...) carrying the
  # client's own logo, so the Kommo brand icon is served locally instead of whatever
  # that particular build ships. Integrations with no icon here keep the Botpress one.
  CLIENT_FACING_INTEGRATIONS = {
    'kommo' => { name: 'Kommo', icon_url: '/assets/images/dashboard/hub/kommo.svg' },
    'googlecalendar' => { name: 'Google Calendar' }
  }.freeze

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
    from = effective_from(from)
    analytics = fetch_analytics(from, to)
    history = AptusHub::UsageHistoryBuilder.build(analytics[:records], analytics[:metrics])

    {
      bot: bot_payload,
      period: period_payload(from, to),
      metrics: admin ? analytics[:metrics] : analytics[:metrics].except(:llm_cost),
      integrations: integrations_payload,
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
      ai_model: config.ai_model,
      logo_url: config.logo_url,
      go_live_on: config.go_live_on&.strftime('%Y-%m-%d')
    }
  end

  # There is no bot history before go-live, so a range starting earlier is pulled
  # forward. The dashboard warns the client before sending such a range, but the
  # numbers themselves are only ever counted from go-live on.
  def effective_from(from)
    [from, config.go_live_on].compact.max
  end

  def period_payload(from, to)
    {
      from: from.strftime('%Y-%m-%d'),
      to: to.strftime('%Y-%m-%d')
    }
  end

  def integrations_payload
    installed = @botpress_client.integrations(bot_id: config.bot_id)

    installed_payload = CLIENT_FACING_INTEGRATIONS.filter_map do |slug, entry|
      integration = installed.find { |item| integration_slug(item[:name]).start_with?(slug) }
      next if integration.nil?

      { name: entry[:name], icon_url: entry[:icon_url] || integration[:icon_url] }
    end

    [WHATSAPP_INTEGRATION, *installed_payload]
  end

  # Botpress prefixes private integrations with the workspace handle
  # ("aptus/kommo-izzy"), which the allowlist above does not care about.
  def integration_slug(name)
    name.to_s.split('/').last.to_s
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

  # The go-live month is only billed from the go-live date on: whatever the bot spent
  # before that was our own testing, and must never reach the client's invoice.
  def month_range(month)
    year, month_number = month.split('-').map(&:to_i)
    from = Date.new(year, month_number, 1)
    [effective_from(from), from.end_of_month]
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
    # The running month has no closed amount yet, so it is neither due nor late.
    return 'open' if month >= today.strftime('%Y-%m')

    due_date_for(month) < today ? 'overdue' : 'pending'
  end

  # Part of the bill is the month's variable API usage, which is only known once the
  # month closes, so a month is always due on the following one.
  def due_date_for(month)
    year, month_number = month.split('-').map(&:to_i)
    reference = Date.new(year, month_number, 1).next_month
    last_day = reference.end_of_month.day
    Date.new(reference.year, reference.month, [config.payment_day, last_day].min)
  end
end
