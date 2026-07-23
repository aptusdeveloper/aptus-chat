export default [
  {
    id: 'rule-1',
    name: 'Boas-vindas',
    active: true,
    crm_pipeline_id: 'pipeline-1',
    trigger_type: 'deal_entered_stage',
    conditions: [
      {
        attribute_key: 'crm_stage_id',
        filter_operator: 'equal_to',
        values: ['stage-1'],
        query_operator: 'AND',
      },
    ],
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
    trigger_type: 'deal_created',
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
