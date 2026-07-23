import axios from 'axios';
import { actions } from '../../crmAutomations';
import types from '../../../mutation-types';
import fixtures from './fixtures';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('#crmAutomations actions', () => {
  beforeEach(() => {
    commit.mockClear();
    axios.get.mockReset();
    axios.post.mockReset();
    axios.patch.mockReset();
    axios.delete.mockReset();
  });

  it('fetches CRM automations', async () => {
    axios.get.mockResolvedValue({ data: { payload: fixtures } });

    await actions.fetch({ commit });

    expect(commit.mock.calls).toEqual([
      [types.SET_CRM_AUTOMATION_UI_FLAG, { isFetching: true }],
      [types.SET_CRM_AUTOMATIONS, fixtures],
      [types.SET_CRM_AUTOMATION_UI_FLAG, { isFetching: false }],
    ]);
  });

  it('creates a CRM automation', async () => {
    axios.post.mockResolvedValue({ data: { payload: fixtures[0] } });

    await actions.create({ commit }, fixtures[0]);

    expect(axios.post).toHaveBeenCalledWith('/api/v1/crm_automation_rules', {
      crm_automation_rule: fixtures[0],
    });
    expect(commit.mock.calls).toEqual([
      [types.SET_CRM_AUTOMATION_UI_FLAG, { isCreating: true }],
      [types.UPSERT_CRM_AUTOMATION, fixtures[0]],
      [types.SET_CRM_AUTOMATION_UI_FLAG, { isCreating: false }],
    ]);
  });

  it('updates a CRM automation', async () => {
    axios.patch.mockResolvedValue({ data: { payload: fixtures[0] } });

    await actions.update({ commit }, { id: fixtures[0].id, active: false });

    expect(axios.patch).toHaveBeenCalledWith(
      '/api/v1/crm_automation_rules/rule-1',
      { crm_automation_rule: { active: false } }
    );
    expect(commit.mock.calls).toEqual([
      [types.SET_CRM_AUTOMATION_UI_FLAG, { isUpdating: true }],
      [types.UPSERT_CRM_AUTOMATION, fixtures[0]],
      [types.SET_CRM_AUTOMATION_UI_FLAG, { isUpdating: false }],
    ]);
  });

  it('deletes a CRM automation', async () => {
    axios.delete.mockResolvedValue({});

    await actions.delete({ commit }, fixtures[0].id);

    expect(commit.mock.calls).toEqual([
      [types.SET_CRM_AUTOMATION_UI_FLAG, { isDeleting: true }],
      [types.DELETE_CRM_AUTOMATION, fixtures[0].id],
      [types.SET_CRM_AUTOMATION_UI_FLAG, { isDeleting: false }],
    ]);
  });

  it('clones a CRM automation', async () => {
    axios.post.mockResolvedValue({ data: { payload: fixtures[1] } });

    await actions.clone({ commit }, fixtures[0].id);

    expect(axios.post).toHaveBeenCalledWith(
      '/api/v1/crm_automation_rules/rule-1/clone'
    );
    expect(commit.mock.calls).toEqual([
      [types.SET_CRM_AUTOMATION_UI_FLAG, { isCloning: true }],
      [types.UPSERT_CRM_AUTOMATION, fixtures[1]],
      [types.SET_CRM_AUTOMATION_UI_FLAG, { isCloning: false }],
    ]);
  });
});
