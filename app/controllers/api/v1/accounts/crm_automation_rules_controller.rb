class Api::V1::Accounts::CrmAutomationRulesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_crm_automation_rule, only: [:show, :update, :destroy, :clone]

  def check_authorization
    authorize(CrmAutomationRule)
  end

  def index
    @crm_automation_rules = Current.account.crm_automation_rules.order(updated_at: :desc)
    load_lookups(@crm_automation_rules)
  end

  def show
    load_lookups([@crm_automation_rule])
  end

  def create
    @crm_automation_rule = Current.account.crm_automation_rules.build(permitted_rule_attributes)
    assign_json_attributes(@crm_automation_rule)
    @crm_automation_rule.save!
    load_lookups([@crm_automation_rule])
  end

  def update
    @crm_automation_rule.assign_attributes(permitted_rule_attributes)
    assign_json_attributes(@crm_automation_rule)
    @crm_automation_rule.save!
    load_lookups([@crm_automation_rule])
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
    load_lookups([@crm_automation_rule])
  end

  private

  def fetch_crm_automation_rule
    @crm_automation_rule = Current.account.crm_automation_rules.find(params[:id])
  end

  def load_lookups(rules)
    pipeline_ids = rules.flat_map { |r| r.triggers.filter_map { |t| t['crm_pipeline_id'] } }.uniq
    stage_ids = rules.flat_map { |r| r.triggers.flat_map { |t| t['stage_ids'] || [] } }.uniq

    @pipelines_by_id = Current.account.crm_pipelines.where(id: pipeline_ids).index_by(&:id)
    @stages_by_id = CrmStage.where(account_id: Current.account.id, id: stage_ids).index_by(&:id)
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
    attrs
  end

  def assign_json_attributes(rule)
    rule.conditions = normalize_collection(payload[:conditions]) if payload.key?(:conditions)
    rule.actions = normalize_collection(payload[:actions]) if payload.key?(:actions)
    rule.triggers = normalize_triggers(payload[:triggers]) if payload.key?(:triggers)
  end

  def normalize_collection(value)
    return [] if value.blank?

    parsed = value.is_a?(String) ? JSON.parse(value) : value
    Array.wrap(parsed).map do |item|
      item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item
    end
  end

  def normalize_triggers(value)
    normalize_collection(value).map do |item|
      next item unless item.respond_to?(:with_indifferent_access)

      item = item.with_indifferent_access
      {
        'trigger_type' => item[:trigger_type],
        'crm_pipeline_id' => item[:crm_pipeline_id].presence,
        'stage_ids' => Array.wrap(item[:stage_ids]).compact_blank,
        'days' => item[:days].presence&.to_i
      }
    end
  end
end
