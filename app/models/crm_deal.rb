# == Schema Information
#
# Table name: crm_deals
#
#  id                :uuid             not null, primary key
#  amount            :decimal(15, 2)
#  close_date        :date
#  currency          :string           default("BRL"), not null
#  custom_attributes :jsonb            not null
#  name              :string           not null
#  position          :float            default(0.0), not null
#  probability       :integer
#  stage_entered_at  :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  assignee_id       :bigint
#  contact_id        :bigint
#  crm_pipeline_id   :uuid             not null
#  crm_stage_id      :uuid             not null
#
# Indexes
#
#  index_crm_deals_on_account_id                       (account_id)
#  index_crm_deals_on_account_id_and_close_date        (account_id,close_date)
#  index_crm_deals_on_account_id_and_crm_stage_id      (account_id,crm_stage_id)
#  index_crm_deals_on_account_id_and_stage_entered_at  (account_id,stage_entered_at)
#  index_crm_deals_on_assignee_id                      (assignee_id)
#  index_crm_deals_on_contact_id                       (contact_id)
#  index_crm_deals_on_crm_pipeline_id                  (crm_pipeline_id)
#  index_crm_deals_on_crm_stage_id                     (crm_stage_id)
#  index_crm_deals_on_custom_attributes                (custom_attributes) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (crm_pipeline_id => crm_pipelines.id)
#  fk_rails_...  (crm_stage_id => crm_stages.id)
#
class CrmDeal < ApplicationRecord
  belongs_to :account
  belongs_to :crm_pipeline
  belongs_to :crm_stage
  belongs_to :contact, optional: true
  belongs_to :assignee, class_name: 'User', inverse_of: :crm_deals, optional: true
  has_many :crm_deal_conversations, dependent: :destroy
  has_many :conversations, through: :crm_deal_conversations
  has_many :agenda_appointments, dependent: :nullify

  validates :account_id, presence: true
  validates :name, presence: true
  validates :probability, numericality: { in: 0..100 }, allow_nil: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_create :set_stage_entered_at
  before_update :update_stage_entered_at, if: :crm_stage_id_changed?
  after_commit :broadcast_deal_event

  scope :open, -> { joins(:crm_stage).where(crm_stages: { is_win: false, is_loss: false }) }
  scope :won, -> { joins(:crm_stage).where(crm_stages: { is_win: true }) }
  scope :lost, -> { joins(:crm_stage).where(crm_stages: { is_loss: true }) }

  private

  def set_stage_entered_at
    self.stage_entered_at = Time.current
  end

  def update_stage_entered_at
    self.stage_entered_at = Time.current
  end

  def broadcast_deal_event
    CrmDealEventBroadcaster.broadcast(self, previous_changes)
  end
end

CrmDeal.prepend_mod_with('CrmDeal')
