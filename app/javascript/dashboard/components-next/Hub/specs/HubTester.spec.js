import { flushPromises, mount } from '@vue/test-utils';
import HubTester from '../HubTester.vue';
import AptusHubAPI from 'dashboard/api/aptusHub';

vi.mock('dashboard/api/aptusHub', () => ({
  default: {
    webchatConfig: vi.fn(),
    feedback: vi.fn(),
  },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

describe('HubTester', () => {
  const scriptUrl = 'https://cdn.botpress.cloud/webchat.js';

  beforeEach(() => {
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  it('does not inject duplicate webchat scripts', async () => {
    const existingScript = document.createElement('script');
    existingScript.src = scriptUrl;
    document.body.appendChild(existingScript);

    AptusHubAPI.webchatConfig.mockResolvedValue({
      data: {
        configured: true,
        script_url: scriptUrl,
      },
    });

    mount(HubTester);
    await flushPromises();

    expect(
      document.querySelectorAll(`script[src="${scriptUrl}"]`)
    ).toHaveLength(1);
  });

  it('renders the empty state when webchat is not configured', async () => {
    AptusHubAPI.webchatConfig.mockResolvedValue({
      data: {
        configured: false,
        script_url: null,
      },
    });

    const wrapper = mount(HubTester);
    await flushPromises();

    expect(wrapper.text()).toContain('HUB.TEST.NOT_CONFIGURED');
  });
});
