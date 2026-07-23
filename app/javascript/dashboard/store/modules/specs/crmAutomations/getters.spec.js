import { getters } from '../../crmAutomations';
import fixtures from './fixtures';

describe('#crmAutomations getters', () => {
  it('returns automations sorted by updated time', () => {
    expect(getters.all({ records: [...fixtures].reverse() })).toEqual(fixtures);
  });

  it('finds automation by id', () => {
    expect(getters.byId({ records: fixtures })('rule-1')).toEqual(fixtures[0]);
  });
});
