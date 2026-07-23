class Api::V1::Accounts::CrmAutomationRulesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_crm_automation_rule, only: [:show, :update, :destroy, :clone]

  def check_authorization
    authorize(CrmAutomationRule)
  end

  def index
    @crm_automation_rules = Current.account
                                           .crm_automation_rules
                                           .includes(:crm_pipeline)
                                           .order(updated_at: :desc)
  end

  def show; end

  def create
    @crm_automation_rule = Current.account.crm_automation_rules.build(permitted_rule_attributes)
    assign_json_attributes(@crm_automation_rule)
    @crm_automation_rule.save!
  end

  def update
    @crm_automation_rule.assign_attributes(permitted_rule_attributes)
    assign_json_attributes(@crm_automation_rule)
    @crm_automation_rule.save!
  end

  def destroy
    @crm_automation_rule.destroy!
    head :ok
  end

  def clone
    @crm_automation_rule = @crm_automation_rule.dup
    @crm_automation_rule.name = "#{@crm_automation_rule.name} (copia)"
    @crm_automation_rule.active = false
    @crm_automation_rule.save!
  end

  private

  def fetch_crm_automation_rule
    @crm_automation_rule = Current.account.crm_automation_rules.find(params[:id])
  end

  def payload
    @payload ||= begin
      raw_payload = params[:crm_automation_rule].presence || params
      if raw_payload.respond_to?(:to_unsafe_h)
        raw_payload.to_unsafe_h.with_indifferent_access
      else
        raw_payload.with_indifferent_access
      end
    end
  end

  def permitted_rule_attributes
    attrs = {}
    attrs[:name] = payload[:name] if payload.key?(:name)
    attrs[:active] = ActiveModel::Type::Boolean.new.cast(payload[:active]) if payload.key?(:active)
    attrs[:trigger_type] = payload[:trigger_type] if payload.key?(:trigger_type)
    attrs[:crm_pipeline_id] = payload[:crm_pipeline_id].presence if payload.key?(:crm_pipeline_id)
    attrs
  end

  def assign_json_attributes(rule)
    rule.conditions = normalize_collection(payload[:conditions]) if payload.key?(:conditions)
    rule.actions = normalize_collection(payload[:actions]) if payload.key?(:actions)
  end

  def normalize_collection(value)
    return [] if value.blank?

    parsed = value.is_a?(String) ? JSON.parse(value) : value
    Array.wrap(parsed).map do |item|
      item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item
    end
  end
end
