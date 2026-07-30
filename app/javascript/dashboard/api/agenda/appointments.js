/* global axios */
import ApiClient from '../ApiClient';

class AgendaAppointmentsAPI extends ApiClient {
  constructor() {
    super('agenda_appointments', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  cancel(id, reason) {
    return axios.post(`${this.url}/${id}/cancel`, { reason });
  }

  reschedule(id, startsAt) {
    return axios.post(`${this.url}/${id}/reschedule`, { starts_at: startsAt });
  }
}

export default new AgendaAppointmentsAPI();
