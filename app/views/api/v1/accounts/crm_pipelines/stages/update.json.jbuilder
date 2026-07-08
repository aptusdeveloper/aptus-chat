json.payload do
  json.partial! 'api/v1/models/crm_stage', formats: [:json], resource: @stage
end
