import { mutations } from '../../crmAutomations';
import types from '../../../mutation-types';
import fixtures from './fixtures';

describe('#crmAutomations mutations', () => {
  it('sets records', () => {
    const state = { records: [] };

    mutations[types.SET_CRM_AUTOMATIONS](state, fixtures);

    expect(state.records).toEqual(fixtures);
  });

  it('upserts records', () => {
    const state = { records: [fixtures[0]] };
    const updated = { ...fixtures[0], active: false };

    mutations[types.UPSERT_CRM_AUTOMATION](state, updated);
    mutations[types.UPSERT_CRM_AUTOMATION](state, fixtures[1]);

    expect(state.records).toEqual([fixtures[1], updated]);
  });

  it('deletes records', () => {
    const state = { records: fixtures };

    mutations[types.DELETE_CRM_AUTOMATION](state, 'rule-1');

    expect(state.records).toEqual([fixtures[1]]);
  });
});
