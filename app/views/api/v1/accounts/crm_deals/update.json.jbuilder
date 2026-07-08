json.payload do
  json.partial! 'api/v1/models/crm_deal', formats: [:json], resource: @deal
end
