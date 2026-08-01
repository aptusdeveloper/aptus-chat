# == Schema Information
#
# Table name: crm_pipelines
#
#  id          :uuid             not null, primary key
#  active      :boolean          default(TRUE), not null
#  description :text
#  is_default  :boolean          default(FALSE), not null
#  name        :string           not null
#  position    :float            default(0.0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_crm_pipelines_on_account_id             (account_id)
#  index_crm_pipelines_on_account_id_and_active  (account_id,active)
#  index_crm_pipelines_one_default_per_account   (account_id,is_default) UNIQUE WHERE (is_default = true)
#
class CrmPipeline < ApplicationRecord
  belongs_to :account
  has_many :crm_stages, dependent: :destroy
  has_many :crm_deals, dependent: :destroy

  validates :account_id, presence: true
  validates :name, presence: true, length: { maximum: 255 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position) }
  scope :default_pipeline, -> { where(is_default: true) }
end

CrmPipeline.prepend_mod_with('CrmPipeline')
