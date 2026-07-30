json.payload do
  json.partial! 'api/v1/models/agenda_professional', formats: [:json], resource: @professional
end
