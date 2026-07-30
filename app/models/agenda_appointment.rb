# == Schema Information
#
# Table name: agenda_appointments
#
#  id                     :uuid             not null, primary key
#  cancellation_reason    :string
#  cancelled_at           :datetime
#  ends_at                :datetime         not null
#  notes                  :text
#  patient_name           :string
#  patient_phone          :string
#  rescheduled            :boolean          default(FALSE), not null
#  source                 :integer          default("bot"), not null
#  starts_at              :datetime         not null
#  status                 :integer          default("confirmed"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  agenda_event_type_id   :uuid             not null
#  agenda_professional_id :uuid             not null
#  contact_id             :integer
#  conversation_id        :integer
#  crm_deal_id            :uuid
#  rescheduled_from_id    :uuid
#
# Indexes
#
#  index_agenda_appointments_on_account_id_and_status        (account_id,status)
#  index_agenda_appointments_on_account_professional_starts  (account_id,agenda_professional_id,starts_at)
#  index_agenda_appointments_on_agenda_event_type_id         (agenda_event_type_id)
#  index_agenda_appointments_on_agenda_professional_id       (agenda_professional_id)
#  index_agenda_appointments_on_contact_id                   (contact_id)
#  index_agenda_appointments_on_conversation_id              (conversation_id)
#  index_agenda_appointments_on_crm_deal_id                  (crm_deal_id)
#  index_agenda_appointments_on_rescheduled_from_id          (rescheduled_from_id)
#
# Foreign Keys
#
#  fk_rails_...  (crm_deal_id => crm_deals.id)
#  fk_rails_...  (agenda_event_type_id => agenda_event_types.id)
#  fk_rails_...  (agenda_professional_id => agenda_professionals.id)
#  fk_rails_...  (rescheduled_from_id => agenda_appointments.id)
#
class AgendaAppointment < ApplicationRecord
  belongs_to :account
  belongs_to :agenda_professional
  belongs_to :agenda_event_type
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true
  belongs_to :crm_deal, optional: true
  belongs_to :rescheduled_from, class_name: 'AgendaAppointment', optional: true

  enum status: { confirmed: 0, cancelled: 1, completed: 2, no_show: 3 }
  enum source: { bot: 0, staff: 1 }

  validates :account_id, presence: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validate :ends_after_starts
  validate :linked_records_belong_to_account

  scope :active, -> { where(status: :confirmed) }

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, 'must be after starts_at')
  end

  def linked_records_belong_to_account
    errors.add(:contact_id, 'must belong to the same account') if contact && contact.account_id != account_id

    errors.add(:conversation_id, 'must belong to the same account') if conversation && conversation.account_id != account_id

    errors.add(:crm_deal_id, 'must belong to the same account') if crm_deal && crm_deal.account_id != account_id
  end
end

AgendaAppointment.prepend_mod_with('AgendaAppointment')
