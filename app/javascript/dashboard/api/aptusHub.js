/* global axios */
import ApiClient from './ApiClient';

class AptusHubAPI extends ApiClient {
  constructor() {
    super('hub', { accountScoped: true });
  }

  overview(params = {}) {
    return axios.get(`${this.url}/overview`, { params });
  }

  performance(params = {}) {
    return axios.get(`${this.url}/performance`, { params });
  }

  webchatConfig() {
    return axios.get(`${this.url}/webchat_config`);
  }

  feedback(payload) {
    return axios.post(`${this.url}/feedback`, payload);
  }

  payments() {
    return axios.get(`${this.url}/payments`);
  }
}

export default new AptusHubAPI();
