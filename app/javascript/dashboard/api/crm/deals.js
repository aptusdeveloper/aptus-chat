/* global axios */
import ApiClient from '../ApiClient';

class CrmDealsAPI extends ApiClient {
  constructor() {
    super('crm_deals', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  move(id, { stageId, position }) {
    return axios.patch(`${this.url}/${id}/move`, {
      stage_id: stageId,
      position,
    });
  }
}

export default new CrmDealsAPI();
