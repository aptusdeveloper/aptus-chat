json.id resource.id
json.name resource.name
json.description resource.description
json.active resource.active
json.position resource.position
json.stages resource.crm_stages.order(:position) do |stage|
  json.partial! 'api/v1/models/crm_stage', formats: [:json], resource: stage
end
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
