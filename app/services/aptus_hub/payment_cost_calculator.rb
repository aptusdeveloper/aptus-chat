class AptusHub::PaymentCostCalculator
  def initialize(config:, exchange_rate_client: AptusHub::ExchangeRateClient.new)
    @config = config
    @exchange_rate_client = exchange_rate_client
  end

  def breakdown(month:, metrics:, payment:, today:)
    build_breakdown(metrics, resolve_exchange_rate(month, payment, today))
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

  def build_breakdown(metrics, rate_info)
    llm_cost_usd = metrics[:llm_cost].to_f
    bot_fixed_cost_usd = config.bot_fixed_cost
    api_cost_usd = llm_cost_usd + bot_fixed_cost_usd
    rate = rate_info[:rate]
    api_cost_brl = api_cost_usd * rate * (1 + config.markup_rate + config.tax_rate)
    monthly_fee_brl = monthly_fee_in_brl(rate)

    {
      llm_cost_usd: llm_cost_usd.round(2),
      bot_fixed_cost_usd: bot_fixed_cost_usd.round(2),
      api_cost_usd: api_cost_usd.round(2),
      usd_brl_rate: rate.round(4),
      rate_is_live: rate_info[:live],
      api_cost_brl: api_cost_brl.round(2),
      monthly_fee: monthly_fee_brl.round(2),
      currency: 'BRL',
      total: (api_cost_brl + monthly_fee_brl).round(2)
    }
  end

  def monthly_fee_in_brl(rate)
    config.currency == 'USD' ? config.monthly_fee * rate : config.monthly_fee
  end
end
