# == Schema Information
#
# Table name: crm_stages
#
#  id              :uuid             not null, primary key
#  color           :string           default("#6B7280")
#  is_loss         :boolean          default(FALSE), not null
#  is_win          :boolean          default(FALSE), not null
#  name            :string           not null
#  position        :float            default(0.0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  crm_pipeline_id :uuid             not null
#
# Indexes
#
#  index_crm_stages_on_account_id                    (account_id)
#  index_crm_stages_on_crm_pipeline_id               (crm_pipeline_id)
#  index_crm_stages_on_crm_pipeline_id_and_position  (crm_pipeline_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (crm_pipeline_id => crm_pipelines.id)
#
class CrmStage < ApplicationRecord
  belongs_to :crm_pipeline
  belongs_to :account
  has_many :crm_deals, dependent: :restrict_with_error

  validates :account_id, presence: true
  validates :name, presence: true, length: { maximum: 255 }
  validates :position, presence: true
  validate :win_and_loss_are_mutually_exclusive

  scope :ordered, -> { order(:position) }

  private

  def win_and_loss_are_mutually_exclusive
    return unless is_win && is_loss

    errors.add(:base, 'Stage cannot be both win and loss')
  end
end

CrmStage.prepend_mod_with('CrmStage')
