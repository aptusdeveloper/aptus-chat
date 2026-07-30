# == Schema Information
#
# Table name: agenda_professionals
#
#  id         :uuid             not null, primary key
#  active     :boolean          default(TRUE), not null
#  color      :string
#  name       :string           not null
#  specialty  :string
#  timezone   :string           default("America/Sao_Paulo"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  user_id    :bigint
#
# Indexes
#
#  index_agenda_professionals_on_account_id             (account_id)
#  index_agenda_professionals_on_account_id_and_active  (account_id,active)
#  index_agenda_professionals_on_user_id                (user_id)
#
class AgendaProfessional < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true
  has_one :agenda_schedule, dependent: :destroy
  has_many :agenda_event_types, dependent: :destroy
  has_many :agenda_appointments, dependent: :restrict_with_error

  validates :account_id, presence: true
  validates :name, presence: true

  after_create :create_default_schedule

  private

  def create_default_schedule
    create_agenda_schedule!(account_id: account_id)
  end
end

AgendaProfessional.prepend_mod_with('AgendaProfessional')
