class AptusHub::PaymentCostCalculator
  def initialize(config:, exchange_rate_client: AptusHub::ExchangeRateClient.new)
    @config = config
    @exchange_rate_client = exchange_rate_client
  end

  def breakdown(month:, metrics:, payment:, today:)
    build_breakdown(month, metrics, resolve_exchange_rate(month, payment, today))
  end

  private

  attr_reader :config, :exchange_rate_client

  def resolve_exchange_rate(month, payment, today)
    return { rate: exchange_rate_client.current_usd_brl_rate, live: true } if month == today.strftime('%Y-%m')
    return { rate: payment[:usd_brl_rate], live: false } if payment&.dig(:usd_brl_rate).present?

    rate = exchange_rate_client.current_usd_brl_rate
    config.freeze_period_data!(month, rate: rate)
    { rate: rate, live: false }
  end

  def build_breakdown(month, metrics, rate_info)
    rate = rate_info[:rate]
    api = api_cost_breakdown(metrics, rate)
    fee = monthly_fee_breakdown(month, rate)

    api.merge(fee).merge(
      usd_brl_rate: rate.round(4),
      rate_is_live: rate_info[:live],
      currency: 'BRL',
      total: (api[:api_cost_brl] + fee[:monthly_fee]).round(2)
    )
  end

  def api_cost_breakdown(metrics, rate)
    llm_cost_usd = metrics[:llm_cost].to_f
    api_cost_usd = llm_cost_usd + config.bot_fixed_cost

    {
      llm_cost_usd: llm_cost_usd.round(2),
      bot_fixed_cost_usd: config.bot_fixed_cost.round(2),
      api_cost_usd: api_cost_usd.round(2),
      api_cost_brl: (api_cost_usd * rate * (1 + config.markup_rate + config.tax_rate)).round(2)
    }
  end

  # The go-live month is charged pro rata: the client pays for the days the bot was
  # actually live, not for the whole month.
  def monthly_fee_breakdown(month, rate)
    days_in_month = Date.new(*month.split('-').map(&:to_i), 1).end_of_month.day
    go_live = config.go_live_on
    billed_days = if go_live && month == go_live.strftime('%Y-%m')
                    days_in_month - go_live.day + 1
                  else
                    days_in_month
                  end

    {
      monthly_fee: (monthly_fee_in_brl(rate) * billed_days / days_in_month).round(2),
      monthly_fee_billed_days: billed_days,
      monthly_fee_month_days: days_in_month
    }
  end

  def monthly_fee_in_brl(rate)
    config.currency == 'USD' ? config.monthly_fee * rate : config.monthly_fee
  end
end
