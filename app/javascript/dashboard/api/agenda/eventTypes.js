import ApiClient from '../ApiClient';

class AgendaEventTypesAPI extends ApiClient {
  constructor() {
    super('agenda_event_types', { accountScoped: true });
  }
}

export default new AgendaEventTypesAPI();
