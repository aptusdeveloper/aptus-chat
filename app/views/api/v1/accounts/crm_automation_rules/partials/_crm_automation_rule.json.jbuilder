json.id resource.id
json.name resource.name
json.active resource.active
json.trigger_type resource.trigger_type
json.crm_pipeline_id resource.crm_pipeline_id
json.conditions resource.conditions
json.actions resource.actions
json.actions_count resource.actions.length

if resource.crm_pipeline
  json.crm_pipeline do
    json.id resource.crm_pipeline.id
    json.name resource.crm_pipeline.name
  end
end

json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
