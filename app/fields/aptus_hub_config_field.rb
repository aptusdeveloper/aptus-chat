require 'administrate/field/base'

class AptusHubConfigField < Administrate::Field::Base
  FIELDS = [
    { key: :enabled, label: 'Enabled', type: :boolean, default: false },
    { key: :bot_id, label: 'Bot ID (Botpress)', type: :string, default: '' },
    { key: :bot_name, label: 'Bot name', type: :string, default: '' },
    { key: :status, label: 'Status', type: :select, options: %w[active paused cancelled], default: 'active' },
    { key: :ai_model, label: 'AI model', type: :string, default: '' },
    { key: :go_live_on, label: 'Bot go-live date', type: :date, default: '', required: true },
    { key: :monthly_fee, label: 'Monthly fee', type: :number, default: 0 },
    { key: :bot_fixed_cost, label: 'Bot fixed cost (USD)', type: :number, default: 10 },
    { key: :currency, label: 'Currency', type: :select, options: %w[BRL USD], default: 'BRL' },
    { key: :payment_day, label: 'Payment due day', type: :number, default: 10 },
    { key: :markup_rate, label: 'Markup (fraction, e.g. 0.14 = 14%)', type: :number, default: 0.14 },
    { key: :tax_rate, label: 'Tax (fraction, e.g. 0.07 = 7%)', type: :number, default: 0.07 },
    { key: :webchat_script_url, label: 'Webchat script URL', type: :string, default: '' }
  ].freeze

  def values
    stored = (data.presence || {}).to_h.symbolize_keys

    FIELDS.each_with_object({}) do |field, result|
      result[field[:key]] = stored.key?(field[:key]) ? stored[field[:key]] : field[:default]
    end
  end

  def to_s
    values.to_json
  end
end
