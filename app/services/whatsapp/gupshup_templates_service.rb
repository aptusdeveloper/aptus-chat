# Fetches the approved templates for a Gupshup app and maps them into the Meta
# component shape the rest of Chatwoot expects (TemplateProcessorService, the
# frontend template picker). The Gupshup template `id` is kept under `gupshup_id`
# because Gupshup's send API addresses templates by id, not by name.
class Whatsapp::GupshupTemplatesService
  BASE_URL = 'https://api.gupshup.io'.freeze
  PAGE_SIZE = 100

  def initialize(app_id:, api_key:)
    @app_id = app_id
    @api_key = api_key
  end

  def templates
    fetch(1, [])
  end

  private

  attr_reader :app_id, :api_key

  def fetch(page_no, acc)
    response = HTTParty.get(
      "#{BASE_URL}/wa/app/#{app_id}/template",
      headers: { 'apikey' => api_key },
      query: { pageNo: page_no, pageSize: PAGE_SIZE }
    )
    return acc unless response.success?

    batch = Array(response.parsed_response['templates']).map { |t| map_template(t) }
    acc += batch
    return acc if batch.size < PAGE_SIZE

    fetch(page_no + 1, acc)
  end

  def map_template(gupshup_template)
    container = parse_container_meta(gupshup_template['containerMeta'])
    {
      'id' => gupshup_template['id'],
      'gupshup_id' => gupshup_template['id'],
      'name' => gupshup_template['elementName'],
      'language' => gupshup_template['languageCode'],
      'status' => gupshup_template['status'].to_s.downcase,
      'category' => gupshup_template['category'],
      'namespace' => gupshup_template['namespace'],
      'parameter_format' => 'POSITIONAL',
      'components' => build_components(gupshup_template, container)
    }
  end

  def parse_container_meta(raw)
    return {} if raw.blank?

    JSON.parse(raw)
  rescue JSON::ParserError
    {}
  end

  def build_components(gupshup_template, container)
    components = []
    components << { 'type' => 'HEADER', 'format' => 'TEXT', 'text' => container['header'] } if container['header'].present?
    body_text = container['data'].presence || gupshup_template['data'].presence
    components << { 'type' => 'BODY', 'text' => body_text } if body_text.present?
    components << { 'type' => 'FOOTER', 'text' => container['footer'] } if container['footer'].present?
    components << { 'type' => 'BUTTONS', 'buttons' => container['buttons'] } if container['buttons'].present?
    components
  end
end
