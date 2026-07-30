# == Schema Information
#
# Table name: agenda_event_types
#
#  id                     :uuid             not null, primary key
#  active                 :boolean          default(TRUE), not null
#  buffer_after_minutes   :integer          default(0), not null
#  buffer_before_minutes  :integer          default(0), not null
#  color                  :string
#  description            :text
#  duration_minutes       :integer          not null
#  minimum_notice_minutes :integer          default(0), not null
#  name                   :string           not null
#  slot_interval_minutes  :integer          default(15), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  agenda_professional_id :uuid
#
# Indexes
#
#  idx_on_account_id_agenda_professional_id_18fb9ca370  (account_id,agenda_professional_id)
#  index_agenda_event_types_on_account_id               (account_id)
#  index_agenda_event_types_on_agenda_professional_id   (agenda_professional_id)
#
# Foreign Keys
#
#  fk_rails_...  (agenda_professional_id => agenda_professionals.id)
#
class AgendaEventType < ApplicationRecord
  belongs_to :account
  belongs_to :agenda_professional, optional: true
  has_many :agenda_appointments, dependent: :restrict_with_error

  validates :account_id, presence: true
  validates :name, presence: true
  validates :duration_minutes, numericality: { greater_than: 0 }
  validates :slot_interval_minutes, numericality: { greater_than: 0 }
end

AgendaEventType.prepend_mod_with('AgendaEventType')
