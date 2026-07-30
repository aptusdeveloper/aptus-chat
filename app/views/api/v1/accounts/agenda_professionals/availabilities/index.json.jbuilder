json.payload do
  json.array! @availabilities do |availability|
    json.partial! 'api/v1/models/agenda_availability', formats: [:json], resource: availability
  end
end
