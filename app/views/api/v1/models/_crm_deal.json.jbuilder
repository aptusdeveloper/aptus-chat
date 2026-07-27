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
    json.thumbnail    resource.contact.avatar_url
  end
end

contact_conversations = resource.contact&.conversations || []
latest_contact_conversation = contact_conversations.max_by do |conversation|
  [conversation.last_activity_at || conversation.created_at, conversation.created_at]
end

if latest_contact_conversation&.assignee
  json.contact_responsible do
    json.type 'agent'
    json.id latest_contact_conversation.assignee.id
    json.name latest_contact_conversation.assignee.name
    json.thumbnail latest_contact_conversation.assignee.avatar_url
  end
elsif latest_contact_conversation&.team
  json.contact_responsible do
    json.type 'team'
    json.id latest_contact_conversation.team.id
    json.name latest_contact_conversation.team.name
    json.icon latest_contact_conversation.team.icon
    json.icon_color latest_contact_conversation.team.icon_color
  end
end

if latest_contact_conversation
  json.latest_contact_conversation do
    json.id latest_contact_conversation.id
    json.inbox_id latest_contact_conversation.inbox_id

    if latest_contact_conversation.inbox
      json.inbox do
        json.id latest_contact_conversation.inbox.id
        json.name latest_contact_conversation.inbox.name
        json.channel_type latest_contact_conversation.inbox.channel_type
      end
    end
  end
end

json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
