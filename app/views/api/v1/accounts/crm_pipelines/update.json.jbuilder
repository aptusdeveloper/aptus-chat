json.payload do
  json.partial! 'api/v1/models/crm_pipeline', formats: [:json], resource: @pipeline
end
