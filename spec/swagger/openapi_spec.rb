require 'rails_helper'
require Rails.root.join('lib/swagger/route_inventory')

RSpec.describe 'OpenAPI document', type: :request do
  let(:document) { JSON.parse(Rails.root.join('swagger/swagger.json').read) }

  it 'is valid against the OpenAPI 3.1.0 meta-schema' do
    expect(skooma_openapi_schema).to be_valid_document
  end

  it 'documenta todas as rotas HTTP classificadas como API' do
    documented = document.fetch('paths').flat_map do |path, item|
      item.keys.grep(/\A(get|post|put|patch|delete)\z/).map { |method| [method.upcase, path] }
    end.to_set

    expect(Swagger::RouteInventory.operation_keys - documented).to be_empty
  end

  it 'usa chaves string nos códigos de resposta para não gerar duplicatas no ReDoc' do
    response_keys = document.fetch('paths').values.flat_map do |path_item|
      path_item.values.filter_map { |operation| operation['responses']&.keys if operation.is_a?(Hash) }
    end.flatten

    expect(response_keys).to all(be_a(String))
  end

  it 'usa a marca AptusChat e metadados em português' do
    expect(document.dig('info', 'title')).to eq('AptusChat API')
    expect(document.dig('info', 'description')).not_to match(/Chatwoot/i)
    expect(document.dig('info', 'description')).to include('Documentação completa')
  end

  it 'identifica visivelmente todas as operações de funcionalidades desabilitadas' do
    disabled = document.fetch('paths').values.flat_map(&:values).select do |operation|
      operation.is_a?(Hash) && operation['x-aptus-status'] == 'disabled'
    end

    expect(disabled).not_to be_empty
    expect(disabled).to all(include('summary', 'description', 'x-aptus-disabled-reason'))
    expect(disabled).to all(satisfy { |operation| operation['summary'].start_with?('Desabilitada no AptusChat') })
  end

  it 'documenta o CRM e os cards de templates de carrossel do WhatsApp' do
    expect(document.fetch('paths')).to include(
      '/api/v1/accounts/{account_id}/crm_pipelines',
      '/api/v1/accounts/{account_id}/crm_pipelines/{crm_pipeline_id}/stages',
      '/api/v1/accounts/{account_id}/crm_deals/{id}/move'
    )
    cards = document.dig('components', 'schemas', 'conversation_message_create_payload', 'properties',
                         'template_params', 'properties', 'processed_params', 'properties', 'cards')
    expect(cards).to include('type' => 'array')
  end
end
