/* global axios */
import ApiClient from '../ApiClient';

class AgendaProfessionalsAPI extends ApiClient {
  constructor() {
    super('agenda_professionals', { accountScoped: true });
  }

  availableSlots(id, params) {
    return axios.get(`${this.url}/${id}/available_slots`, { params });
  }
}

export default new AgendaProfessionalsAPI();
