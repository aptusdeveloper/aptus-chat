# == Schema Information
#
# Table name: agenda_schedules
#
#  id                     :uuid             not null, primary key
#  name                   :string           default("Padrão"), not null
#  timezone               :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  agenda_professional_id :uuid             not null
#
# Indexes
#
#  index_agenda_schedules_on_account_id              (account_id)
#  index_agenda_schedules_on_agenda_professional_id  (agenda_professional_id)
#
# Foreign Keys
#
#  fk_rails_...  (agenda_professional_id => agenda_professionals.id)
#
class AgendaSchedule < ApplicationRecord
  belongs_to :account
  belongs_to :agenda_professional
  has_many :agenda_availabilities, dependent: :destroy

  validates :account_id, presence: true
  validates :name, presence: true
end

AgendaSchedule.prepend_mod_with('AgendaSchedule')
