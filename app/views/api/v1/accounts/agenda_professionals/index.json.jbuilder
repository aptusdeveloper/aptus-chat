json.payload do
  json.array! @professionals do |professional|
    json.partial! 'api/v1/models/agenda_professional', formats: [:json], resource: professional
  end
end
