json.id resource.id
json.agenda_professional_id resource.agenda_professional_id
json.agenda_event_type_id resource.agenda_event_type_id
json.contact_id resource.contact_id
json.conversation_id resource.conversation_id
json.crm_deal_id resource.crm_deal_id
json.starts_at resource.starts_at.iso8601
json.ends_at resource.ends_at.iso8601
json.status resource.status
json.rescheduled resource.rescheduled
json.rescheduled_from_id resource.rescheduled_from_id
json.cancelled_at resource.cancelled_at&.iso8601
json.cancellation_reason resource.cancellation_reason
json.source resource.source
json.patient_name resource.patient_name
json.patient_phone resource.patient_phone
json.notes resource.notes

if resource.agenda_professional
  json.agenda_professional do
    json.id resource.agenda_professional.id
    json.name resource.agenda_professional.name
    json.color resource.agenda_professional.color
  end
end

if resource.agenda_event_type
  json.agenda_event_type do
    json.id resource.agenda_event_type.id
    json.name resource.agenda_event_type.name
    json.duration_minutes resource.agenda_event_type.duration_minutes
  end
end

if resource.contact
  json.contact do
    json.id resource.contact.id
    json.name resource.contact.name
    json.email resource.contact.email
    json.phone_number resource.contact.phone_number
    json.thumbnail resource.contact.avatar_url
  end
end

if resource.crm_deal
  json.crm_deal do
    json.id resource.crm_deal.id
    json.name resource.crm_deal.name
    json.contact_id resource.crm_deal.contact_id
  end
end

json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
