json.payload do
  json.partial! 'api/v1/models/agenda_availability', formats: [:json], resource: @availability
end
