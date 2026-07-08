json.payload do
  json.array! @stages do |stage|
    json.partial! 'api/v1/models/crm_stage', formats: [:json], resource: stage
  end
end
