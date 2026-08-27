# Gupshup is a WhatsApp BSP that hosts the number on Meta's Cloud API (CAPI) but
# exposes its own send API (`/wa/api/v1/msg`, form-urlencoded) instead of the raw
# Graph API. Inbound webhooks are configured in the Gupshup console to use the
# "Meta format (v3)" payload, so they are parsed by
# `Whatsapp::IncomingMessageGupshupService` (a thin subclass of the Cloud service).
#
# provider_config keys:
#   api_key             - Gupshup API key (permanent, from the app's Settings tab)
#   app_name            - Gupshup app name, sent as `src.name`
#   app_id              - Gupshup app UUID, used for template listing and media
#   phone_number_id     - Meta phone number id (matches the inbound webhook metadata)
#   business_account_id - WABA id (optional, kept for parity with the Cloud provider)
class Whatsapp::Providers::GupshupService < Whatsapp::Providers::BaseService
  BASE_URL = 'https://api.gupshup.io'.freeze

  def send_message(phone_number, message)
    @message = message

    if message.attachments.present?
      send_attachment_message(phone_number, message)
    elsif message.content_type == 'input_select'
      send_interactive_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  def send_template(phone_number, template_info, message)
    template = find_gupshup_template(template_info)
    raise ArgumentError, "Gupshup template not found: #{template_info[:name]} (#{template_info[:lang_code]})" if template.blank?

    body = base_params(phone_number).merge(
      template: { id: template['gupshup_id'], params: flatten_template_params(template_info[:parameters]) }.to_json
    )
    header_media = template_header_media(template_info[:parameters])
    body[:message] = header_media.to_json if header_media.present?

    process_response(post('/wa/api/v1/template/msg', body), message)
  end

  def sync_templates
    # ensures a channel with a broken config stops retrying the sync
    whatsapp_channel.mark_message_templates_updated
    templates = Whatsapp::GupshupTemplatesService.new(app_id: app_id, api_key: provider_api_key).templates
    whatsapp_channel.update(message_templates: templates, message_templates_last_updated: Time.now.utc) if templates.present?
  end

  def validate_provider_config?
    HTTParty.get("#{BASE_URL}/wa/app/#{app_id}/template", headers: api_headers, query: { pageSize: 1 }).success?
  end

  def api_headers
    { 'apikey' => provider_api_key }
  end

  def media_url(media_id)
    "https://filemanager.gupshup.io/wa/#{app_id}/wa/media/#{media_id}?download=false"
  end

  # Gupshup replies with `{ "status": "submitted", "messageId": "..." }`, not the
  # Meta shape (`{ "messages": [{ "id": "..." }] }`) that BaseService#process_response expects.
  def process_response(response, message)
    parsed = response.parsed_response
    parsed = {} unless parsed.is_a?(Hash)

    if response.success? && parsed['status'] != 'error'
      parsed['messageId']
    else
      handle_error(response, message)
      nil
    end
  end

  def error_message(response)
    parsed = response.parsed_response
    return unless parsed.is_a?(Hash)

    parsed['message'].presence || parsed.dig('error', 'message')
  end

  private

  def post(path, body)
    HTTParty.post(
      "#{BASE_URL}#{path}",
      headers: api_headers.merge('Content-Type' => 'application/x-www-form-urlencoded'),
      body: body
    )
  end

  def base_params(phone_number)
    {
      channel: 'whatsapp',
      source: source_number,
      destination: phone_number
    }.merge('src.name' => app_name)
  end

  def source_number
    whatsapp_channel.phone_number.to_s.delete('+')
  end

  def app_name
    whatsapp_channel.provider_config['app_name']
  end

  def app_id
    whatsapp_channel.provider_config['app_id']
  end

  def provider_api_key
    whatsapp_channel.provider_config['api_key']
  end

  def send_text_message(phone_number, message)
    body = base_params(phone_number).merge(message: { type: 'text', text: message.outgoing_content }.to_json)
    process_response(post('/wa/api/v1/msg', body), message)
  end

  def send_attachment_message(phone_number, message)
    payload = attachment_message_payload(message.attachments.first, message)
    body = base_params(phone_number).merge(message: payload.to_json)
    process_response(post('/wa/api/v1/msg', body), message)
  end

  def attachment_message_payload(attachment, message)
    url = attachment.download_url
    caption = message.outgoing_content

    case attachment.file_type
    when 'image'
      { type: 'image', originalUrl: url, previewUrl: url, caption: caption }
    when 'audio'
      { type: 'audio', url: url }
    when 'video'
      { type: 'video', url: url, caption: caption }
    when 'sticker'
      { type: 'sticker', url: url }
    else
      { type: 'file', url: url, filename: attachment.file.filename.to_s, caption: caption }
    end
  end

  def send_interactive_message(phone_number, message)
    items = message.content_attributes['items'] || []
    payload = items.length <= 3 ? quick_reply_payload(message, items) : list_payload(message, items)
    body = base_params(phone_number).merge(message: payload.to_json)
    process_response(post('/wa/api/v1/msg', body), message)
  end

  def quick_reply_payload(message, items)
    {
      type: 'quick_reply',
      msgid: "qr_#{message.id}",
      content: { type: 'text', text: message.outgoing_content },
      options: items.map { |item| { type: 'text', title: item['title'] } }
    }
  end

  def list_payload(message, items)
    button_label = I18n.t('conversations.messages.whatsapp.list_button_label')
    {
      type: 'list',
      title: '',
      body: message.outgoing_content,
      msgid: "list_#{message.id}",
      globalButtons: [{ type: 'text', title: button_label }],
      items: [
        {
          title: button_label,
          options: items.map { |item| { type: 'text', title: item['title'], postbackText: item['value'].to_s } }
        }
      ]
    }
  end

  def find_gupshup_template(template_info)
    (whatsapp_channel.message_templates || []).find do |t|
      t['name'] == template_info[:name] &&
        t['language']&.downcase == template_info[:lang_code]&.downcase &&
        t['gupshup_id'].present?
    end
  end

  # TemplateProcessorService hands us Meta component-format params; Gupshup's
  # `template.params` is a flat, ordered list of the body placeholder values.
  def flatten_template_params(components)
    body = component_by_type(components, 'body')
    Array(body && component_parameters(body)).filter_map { |param| param_value(param) }
  end

  def param_value(param)
    param[:text] || param['text'] || param.dig(:image, :link) || param.dig('image', 'link')
  end

  def template_header_media(components)
    header = component_by_type(components, 'header')
    param = Array(header && component_parameters(header)).first
    return if param.blank?

    kind, media = header_media_pair(param)
    return if kind.blank?

    { type: kind }.merge(kind => { link: media[:link] || media['link'] })
  end

  def header_media_pair(param)
    %w[image video document].each do |kind|
      media = param[kind.to_sym] || param[kind]
      return [kind, media] if media.present?
    end
    [nil, nil]
  end

  def component_by_type(components, type)
    Array(components).find { |c| (c[:type] || c['type']).to_s == type }
  end

  def component_parameters(component)
    component[:parameters] || component['parameters']
  end
end
