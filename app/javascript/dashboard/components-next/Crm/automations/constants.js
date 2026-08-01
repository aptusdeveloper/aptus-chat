export const TRIGGERS = [
  {
    id: 'deal_created',
    labelKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_CREATED',
    descriptionKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_CREATED_DESCRIPTION',
    icon: 'i-lucide-plus-circle',
  },
  {
    id: 'deal_entered_stage',
    labelKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_ENTERED_STAGE',
    descriptionKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_ENTERED_STAGE_DESCRIPTION',
    icon: 'i-lucide-log-in',
    needsStage: true,
  },
  {
    id: 'deal_stage_changed',
    labelKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_STAGE_CHANGED',
    descriptionKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_STAGE_CHANGED_DESCRIPTION',
    icon: 'i-lucide-arrow-right-left',
  },
  {
    id: 'deal_updated',
    labelKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_UPDATED',
    descriptionKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_UPDATED_DESCRIPTION',
    icon: 'i-lucide-refresh-cw',
  },
  {
    id: 'deal_won',
    labelKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_WON',
    descriptionKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_WON_DESCRIPTION',
    icon: 'i-lucide-trophy',
  },
  {
    id: 'deal_lost',
    labelKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_LOST',
    descriptionKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_LOST_DESCRIPTION',
    icon: 'i-lucide-circle-x',
  },
  {
    id: 'deal_stagnant',
    labelKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_STAGNANT',
    descriptionKey: 'CRM.AUTOMATIONS.TRIGGERS.DEAL_STAGNANT_DESCRIPTION',
    icon: 'i-lucide-clock',
    needsDays: true,
  },
  {
    id: 'deal_close_date_approaching',
    labelKey: 'CRM.AUTOMATIONS.TRIGGERS.CLOSE_DATE_APPROACHING',
    descriptionKey:
      'CRM.AUTOMATIONS.TRIGGERS.CLOSE_DATE_APPROACHING_DESCRIPTION',
    icon: 'i-lucide-calendar-clock',
    needsDays: true,
  },
];

export const CONDITION_ATTRIBUTES = [
  {
    id: 'crm_stage_id',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.ATTRIBUTES.STAGE',
    input: 'stage',
  },
  {
    id: 'assignee_id',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.ATTRIBUTES.ASSIGNEE',
    input: 'agent',
  },
  {
    id: 'amount',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.ATTRIBUTES.AMOUNT',
    input: 'number',
  },
  {
    id: 'probability',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.ATTRIBUTES.PROBABILITY',
    input: 'number',
  },
  {
    id: 'close_date',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.ATTRIBUTES.CLOSE_DATE',
    input: 'date',
  },
  {
    id: 'days_in_stage',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.ATTRIBUTES.DAYS_IN_STAGE',
    input: 'number',
  },
];

export const OPERATORS = [
  { id: 'equal_to', labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.EQUAL_TO' },
  {
    id: 'not_equal_to',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.NOT_EQUAL_TO',
  },
  {
    id: 'greater_than',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.GREATER_THAN',
  },
  {
    id: 'less_than',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.LESS_THAN',
  },
  { id: 'gte', labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.GTE' },
  { id: 'lte', labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.LTE' },
  { id: 'contains', labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.CONTAINS' },
  {
    id: 'is_present',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.IS_PRESENT',
    hidesValue: true,
  },
  {
    id: 'is_not_present',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.IS_NOT_PRESENT',
    hidesValue: true,
  },
  {
    id: 'days_before',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.DAYS_BEFORE',
  },
  {
    id: 'is_today',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.IS_TODAY',
    hidesValue: true,
  },
  {
    id: 'is_past',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.IS_PAST',
    hidesValue: true,
  },
  {
    id: 'is_future',
    labelKey: 'CRM.AUTOMATIONS.CONDITIONS.OPERATORS.IS_FUTURE',
    hidesValue: true,
  },
];

export const ACTIONS = [
  {
    id: 'send_lead_message',
    labelKey: 'CRM.AUTOMATIONS.ACTIONS.TYPES.SEND_LEAD_MESSAGE',
    icon: 'i-lucide-send',
  },
  {
    id: 'change_stage',
    labelKey: 'CRM.AUTOMATIONS.ACTIONS.TYPES.CHANGE_STAGE',
    icon: 'i-lucide-move-right',
  },
  {
    id: 'change_pipeline',
    labelKey: 'CRM.AUTOMATIONS.ACTIONS.TYPES.CHANGE_PIPELINE',
    icon: 'i-lucide-git-branch',
  },
  {
    id: 'assign_agent',
    labelKey: 'CRM.AUTOMATIONS.ACTIONS.TYPES.ASSIGN_AGENT',
    icon: 'i-lucide-user-plus',
  },
  {
    id: 'update_field',
    labelKey: 'CRM.AUTOMATIONS.ACTIONS.TYPES.UPDATE_FIELD',
    icon: 'i-lucide-square-pen',
  },
  {
    id: 'send_webhook_event',
    labelKey: 'CRM.AUTOMATIONS.ACTIONS.TYPES.SEND_WEBHOOK',
    icon: 'i-lucide-webhook',
  },
];

export const MESSAGE_KINDS = [
  {
    id: 'text',
    labelKey: 'CRM.AUTOMATIONS.MESSAGE.KINDS.TEXT',
    icon: 'i-lucide-message-square',
  },
  {
    id: 'media',
    labelKey: 'CRM.AUTOMATIONS.MESSAGE.KINDS.MEDIA',
    icon: 'i-lucide-paperclip',
  },
  {
    id: 'buttons',
    labelKey: 'CRM.AUTOMATIONS.MESSAGE.KINDS.BUTTONS',
    icon: 'i-lucide-list-checks',
  },
  {
    id: 'template',
    labelKey: 'CRM.AUTOMATIONS.MESSAGE.KINDS.TEMPLATE',
    icon: 'i-lucide-file-check',
  },
];
