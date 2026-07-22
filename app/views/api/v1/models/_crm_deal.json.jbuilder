json.id resource.id
json.name resource.name
json.amount resource.amount
json.currency resource.currency
json.close_date resource.close_date
json.probability resource.probability
json.position resource.position
json.custom_attributes resource.custom_attributes
json.crm_pipeline_id resource.crm_pipeline_id
json.crm_stage_id resource.crm_stage_id
json.contact_id resource.contact_id
json.assignee_id resource.assignee_id

if resource.assignee
  json.assignee do
    json.id   resource.assignee.id
    json.name resource.assignee.name
  end
end

if resource.contact
  json.contact do
    json.id           resource.contact.id
    json.name         resource.contact.name
    json.email        resource.contact.email
    json.phone_number resource.contact.phone_number
  end
end

json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
