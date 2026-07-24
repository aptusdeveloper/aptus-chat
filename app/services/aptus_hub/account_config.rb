class AptusHub::AccountConfig
  HUB_KEY = 'aptus_hub'.freeze
  FEEDBACK_LIMIT = 50

  attr_reader :account

  def initialize(account)
    @account = account
  end

  def raw
    account.custom_attributes.to_h.fetch(HUB_KEY, {}).with_indifferent_access
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(raw[:enabled])
  end

  def bot_id
    raw[:bot_id].presence
  end

  def available?
    enabled? && bot_id.present?
  end

  def bot_name
    raw[:bot_name].presence || raw[:name].presence || account.name
  end

  def status
    raw[:status].presence || 'active'
  end

  def ai_model
    raw[:ai_model].presence || raw[:aiModel].presence
  end

  def monthly_fee
    numeric_value(raw[:monthly_fee].presence || raw[:monthlyFee], 0)
  end

  def bot_fixed_cost
    numeric_value(raw[:bot_fixed_cost].presence || raw[:botFixedCost], 10)
  end

  def markup_rate
    numeric_value(raw[:markup_rate].presence || raw[:markupRate], 0.14)
  end

  def tax_rate
    numeric_value(raw[:tax_rate].presence || raw[:taxRate], 0.07)
  end

  def currency
    value = raw[:currency].presence || 'BRL'
    value.to_s.upcase == 'USD' ? 'USD' : 'BRL'
  end

  def payment_day
    day = (
      raw[:payment_day].presence ||
      raw[:paymentDate].presence ||
      raw[:payment_date].presence ||
      10
    ).to_i
    day.clamp(1, 31)
  end

  def webchat_script_url
    raw[:webchat_script_url].presence ||
      raw[:webchatScriptUrl].presence ||
      extract_script_src(raw[:webchat_embed].presence)
  end

  def payments
    Array.wrap(raw[:payments]).filter_map do |payment|
      attrs = payment.with_indifferent_access
      month = attrs[:month].to_s
      next if month.blank?

      {
        month: month,
        status: attrs[:status].to_s == 'paid' ? 'paid' : 'pending',
        paid_at: attrs[:paid_at].presence || attrs[:paidAt].presence,
        usd_brl_rate: numeric_value(attrs[:usd_brl_rate].presence || attrs[:usdBrlRate], nil)
      }
    end
  end

  def serialized_for_account
    {
      enabled: enabled?,
      bot_id: bot_id
    }.compact
  end

  def append_feedback!(payload)
    current_feedback = Array.wrap(raw[:feedback]).last(FEEDBACK_LIMIT - 1)
    merged_hub = raw.to_h.merge('feedback' => current_feedback + [payload])

    account.custom_attributes = account.custom_attributes.to_h.merge(HUB_KEY => merged_hub)
    account.save!
  end

  def freeze_exchange_rate!(month, rate)
    current_payments = Array.wrap(raw[:payments]).map(&:with_indifferent_access)
    existing = current_payments.find { |payment| payment[:month].to_s == month }

    if existing
      existing[:usd_brl_rate] = rate
    else
      current_payments << { 'month' => month, 'status' => 'pending', 'usd_brl_rate' => rate }
    end

    merged_hub = raw.to_h.merge('payments' => current_payments)
    account.custom_attributes = account.custom_attributes.to_h.merge(HUB_KEY => merged_hub)
    account.save!
  end

  private

  def numeric_value(value, fallback)
    return fallback if value.blank?

    Float(value)
  rescue ArgumentError, TypeError
    fallback
  end

  def extract_script_src(embed_code)
    return if embed_code.blank?

    embed_code.to_s[/src=["']([^"']+)["']/, 1]
  end
end
