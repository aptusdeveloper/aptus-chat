FactoryBot.define do
  factory :agenda_professional do
    account
    sequence(:name) { |n| "Dra. Professional #{n}" }
    specialty { 'Clínico Geral' }
    timezone { 'America/Sao_Paulo' }
    active { true }
  end

  factory :agenda_availability do
    agenda_schedule { association(:agenda_professional, account: account).agenda_schedule }
    account
    day_of_week { 1 }
    start_hour { 8 }
    start_minutes { 0 }
    end_hour { 12 }
    end_minutes { 0 }
    unavailable { false }
  end

  factory :agenda_event_type do
    account
    agenda_professional { nil }
    sequence(:name) { |n| "Procedimento #{n}" }
    duration_minutes { 30 }
    buffer_before_minutes { 0 }
    buffer_after_minutes { 0 }
    minimum_notice_minutes { 0 }
    slot_interval_minutes { 15 }
    active { true }
  end

  factory :agenda_appointment do
    account { agenda_professional.account }
    agenda_professional
    agenda_event_type { association :agenda_event_type, account: agenda_professional.account }
    starts_at { 1.day.from_now.change(hour: 9, min: 0) }
    ends_at { starts_at + 30.minutes }
    status { 'confirmed' }
    source { 'bot' }
  end
end
