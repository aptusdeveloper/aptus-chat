class AptusHub::ExchangeRateClient
  class Error < StandardError; end

  API_URL = 'https://economia.awesomeapi.com.br/json/last/USD-BRL'.freeze
  # Short-lived cache: a closed month's rate is frozen on the account instead (see
  # AptusHub::AccountConfig#freeze_period_data!), so this only protects the live/current
  # month rate from repeated lookups within the same minute.
  CACHE_TTL = 1.minute

  def current_usd_brl_rate
    cached = Redis::Alfred.get(Redis::RedisKeys::APTUS_HUB_EXCHANGE_RATE_KEY)
    return Float(cached) if cached.present?

    response = HTTParty.get(API_URL, timeout: 10)

    raise Error, 'Nao foi possivel buscar a cotacao do dolar agora.' unless response.success?

    body = response.parsed_response
    body = JSON.parse(response.body) if body.is_a?(String)
    rate = body.dig('USDBRL', 'bid')

    raise Error, 'Nao foi possivel ler a cotacao do dolar agora.' if rate.blank?

    Float(rate).tap do |value|
      Redis::Alfred.setex(Redis::RedisKeys::APTUS_HUB_EXCHANGE_RATE_KEY, value, CACHE_TTL)
    end
  rescue Error
    raise
  rescue StandardError => e
    Rails.logger.error "[AptusHub] Exchange rate lookup failed: #{e.message}"
    raise Error, 'Nao foi possivel buscar a cotacao do dolar agora.'
  end
end
