json.payload do
  json.array! @event_types do |event_type|
    json.partial! 'api/v1/models/agenda_event_type', formats: [:json], resource: event_type
  end
end
