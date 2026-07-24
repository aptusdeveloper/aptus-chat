class AptusHub::ExchangeRateClient
  class Error < StandardError; end

  API_URL = 'https://economia.awesomeapi.com.br/json/last/USD-BRL'.freeze

  def current_usd_brl_rate
    response = HTTParty.get(API_URL, timeout: 10)

    raise Error, 'Nao foi possivel buscar a cotacao do dolar agora.' unless response.success?

    body = response.parsed_response
    body = JSON.parse(response.body) if body.is_a?(String)
    rate = body.dig('USDBRL', 'bid')

    raise Error, 'Nao foi possivel ler a cotacao do dolar agora.' if rate.blank?

    Float(rate)
  rescue Error
    raise
  rescue StandardError => e
    Rails.logger.error "[AptusHub] Exchange rate lookup failed: #{e.message}"
    raise Error, 'Nao foi possivel buscar a cotacao do dolar agora.'
  end
end
