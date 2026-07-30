/* global axios */
import ApiClient from '../ApiClient';

class AgendaAvailabilitiesAPI extends ApiClient {
  constructor() {
    super('agenda_professionals', { accountScoped: true });
  }

  get(professionalId) {
    return axios.get(`${this.url}/${professionalId}/availabilities`);
  }

  create(professionalId, data) {
    return axios.post(`${this.url}/${professionalId}/availabilities`, data);
  }

  update(professionalId, id, data) {
    return axios.patch(
      `${this.url}/${professionalId}/availabilities/${id}`,
      data
    );
  }

  delete(professionalId, id) {
    return axios.delete(`${this.url}/${professionalId}/availabilities/${id}`);
  }

  bulkReplaceWeekly(professionalId, agendaAvailabilities) {
    return axios.put(
      `${this.url}/${professionalId}/availabilities/bulk_replace_weekly`,
      { agenda_availabilities: agendaAvailabilities }
    );
  }
}

export default new AgendaAvailabilitiesAPI();
