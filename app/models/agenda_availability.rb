# == Schema Information
#
# Table name: agenda_availabilities
#
#  id                 :uuid             not null, primary key
#  date               :date
#  day_of_week        :integer
#  end_hour           :integer
#  end_minutes        :integer
#  start_hour         :integer
#  start_minutes      :integer
#  unavailable        :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  agenda_schedule_id :uuid             not null
#
# Indexes
#
#  idx_on_account_id_agenda_schedule_id_29ac4bdea8             (account_id,agenda_schedule_id)
#  idx_on_agenda_schedule_id_day_of_week_d66c9549c9            (agenda_schedule_id,day_of_week)
#  index_agenda_availabilities_on_agenda_schedule_id           (agenda_schedule_id)
#  index_agenda_availabilities_on_agenda_schedule_id_and_date  (agenda_schedule_id,date)
#
# Foreign Keys
#
#  fk_rails_...  (agenda_schedule_id => agenda_schedules.id)
#
class AgendaAvailability < ApplicationRecord
  belongs_to :account
  belongs_to :agenda_schedule

  validates :account_id, presence: true
  validate :day_of_week_xor_date
  validates :start_hour, presence: true, inclusion: 0..23, unless: :unavailable_all_day?
  validates :end_hour, presence: true, inclusion: 0..23, unless: :unavailable_all_day?
  validates :start_minutes, presence: true, inclusion: 0..59, unless: :unavailable_all_day?
  validates :end_minutes, presence: true, inclusion: 0..59, unless: :unavailable_all_day?

  scope :weekly, -> { where(date: nil) }
  scope :date_overrides, -> { where.not(date: nil) }

  def date_override?
    date.present?
  end

  private

  def unavailable_all_day?
    date_override? && unavailable?
  end

  def day_of_week_xor_date
    return if day_of_week.present? ^ date.present?

    errors.add(:base, 'Exactly one of day_of_week or date must be present')
  end
end

AgendaAvailability.prepend_mod_with('AgendaAvailability')
