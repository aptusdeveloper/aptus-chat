<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import AptusHubAPI from 'dashboard/api/aptusHub';
import { hubErrorMessage } from './utils';

const WEBCHAT_LOADER_SCRIPT_URL =
  'https://cdn.botpress.cloud/webchat/v3.7/inject.js';
const WEBCHAT_CONTAINER_ID = 'aptus-hub-webchat-container';

const { t } = useI18n();
const config = ref(null);
const isLoading = ref(false);
const isScriptLoading = ref(false);
const error = ref('');

function appendScript(src, { defer = false, waitForLoad = false } = {}) {
  const existing = document.querySelector(`script[src="${src}"]`);
  if (existing) return Promise.resolve();

  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = src;
    // async = false preserva a ordem de execução entre os dois scripts
    // (o loader precisa rodar antes do script de config do bot)
    script.async = false;
    script.defer = defer;
    script.dataset.aptusHubWebchat = 'true';

    if (waitForLoad) {
      script.onload = resolve;
      script.onerror = reject;
    }

    document.body.appendChild(script);
    if (!waitForLoad) resolve();
  });
}

function ensureWebchatWidget(scriptUrl) {
  document
    .querySelectorAll('script[data-aptus-hub-webchat="true"]')
    .forEach(script => {
      if (
        script.src !== WEBCHAT_LOADER_SCRIPT_URL &&
        script.src !== scriptUrl
      ) {
        script.remove();
      }
    });

  return appendScript(WEBCHAT_LOADER_SCRIPT_URL)
    .then(() => appendScript(scriptUrl, { defer: true, waitForLoad: true }))
    .then(() => {
      // O script do bot inicializa no modo "fab" (bolinha flutuante) por padrão.
      // window.botpress.config() troca pro modo embutido, renderizando dentro do nosso container.
      window.botpress?.config?.({
        configuration: { embeddedChatId: WEBCHAT_CONTAINER_ID },
      });
    });
}

async function loadConfig() {
  isLoading.value = true;
  error.value = '';

  try {
    const response = await AptusHubAPI.webchatConfig();
    config.value = response.data;

    if (response.data.configured && response.data.script_url) {
      isScriptLoading.value = true;
      await ensureWebchatWidget(response.data.script_url);
    }
  } catch (apiError) {
    error.value = hubErrorMessage(apiError);
  } finally {
    isLoading.value = false;
    isScriptLoading.value = false;
  }
}

onMounted(() => {
  loadConfig();
});
</script>

<template>
  <div class="h-full flex flex-col px-8 pb-8 pt-4 gap-4">
    <div class="shrink-0">
      <h2 class="text-lg font-semibold text-n-slate-12">
        {{ t('HUB.TEST.TITLE') }}
      </h2>
      <p class="text-sm text-n-slate-10">
        {{ t('HUB.TEST.SUBTITLE') }}
      </p>
    </div>

    <div
      v-if="error"
      class="shrink-0 rounded-lg border border-n-ruby-5 bg-n-ruby-2 px-4 py-3 text-sm text-n-ruby-11"
    >
      {{ error }}
    </div>

    <div
      v-if="isLoading"
      class="flex items-center gap-2 text-sm text-n-slate-10"
    >
      <i class="i-lucide-loader-2 w-4 h-4 animate-spin" />
      {{ t('HUB.TEST.LOADING') }}
    </div>

    <template v-else>
      <section
        v-if="!config?.configured"
        class="rounded-lg border border-dashed border-n-weak bg-white dark:bg-n-solid-2 p-8 text-center"
      >
        <i
          class="i-lucide-message-circle-off w-10 h-10 text-n-slate-8 mx-auto mb-3"
        />
        <p class="text-sm font-medium text-n-slate-11">
          {{ t('HUB.TEST.NOT_CONFIGURED') }}
        </p>
      </section>

      <div v-else class="flex-1 min-h-0 flex flex-col">
        <div
          v-if="isScriptLoading"
          class="flex-1 flex items-center justify-center text-n-slate-9"
        >
          <i class="i-lucide-loader-2 w-8 h-8 animate-spin" />
        </div>
        <div
          :id="WEBCHAT_CONTAINER_ID"
          class="flex-1 min-h-0"
          :class="{ hidden: isScriptLoading }"
        />
      </div>
    </template>
  </div>
</template>
