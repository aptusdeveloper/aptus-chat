export default [
  {
    id: 'rule-1',
    name: 'Boas-vindas',
    active: true,
    triggers: [
      {
        trigger_type: 'deal_entered_stage',
        crm_pipeline_id: 'pipeline-1',
        crm_pipeline_name: 'Pipeline 1',
        stage_ids: ['stage-1'],
        stage_names: ['Qualificacao'],
        days: null,
      },
    ],
    conditions: [],
    actions: [
      {
        action_name: 'send_lead_message',
        action_params: {
          content: 'Ola!',
          content_type: 'text',
        },
      },
    ],
    updated_at: 2,
  },
  {
    id: 'rule-2',
    name: 'Webhook',
    active: false,
    triggers: [
      {
        trigger_type: 'deal_created',
        crm_pipeline_id: null,
        crm_pipeline_name: null,
        stage_ids: [],
        stage_names: [],
        days: null,
      },
    ],
    conditions: [],
    actions: [
      {
        action_name: 'send_webhook_event',
        action_params: { url: 'https://example.com' },
      },
    ],
    updated_at: 1,
  },
];
