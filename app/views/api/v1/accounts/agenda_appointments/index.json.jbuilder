json.payload do
  json.array! @appointments do |appointment|
    json.partial! 'api/v1/models/agenda_appointment', formats: [:json], resource: appointment
  end
end
