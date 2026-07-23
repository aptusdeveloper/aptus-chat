<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AptusHubAPI from 'dashboard/api/aptusHub';
import { hubErrorMessage } from './utils';

const { t } = useI18n();
const config = ref(null);
const isLoading = ref(false);
const isScriptLoading = ref(false);
const isSending = ref(false);
const error = ref('');
const comment = ref('');
const conversationId = ref('');

function normalizeEventPayload(data) {
  if (typeof data !== 'string') return data;

  try {
    return JSON.parse(data);
  } catch {
    return {};
  }
}

function extractConversationId(payload) {
  const data = normalizeEventPayload(payload);
  if (!data || typeof data !== 'object') return '';

  return (
    data.conversationId ||
    data.conversation_id ||
    data.payload?.conversationId ||
    data.payload?.conversation_id ||
    data.data?.conversationId ||
    data.data?.conversation_id ||
    data.conversation?.id ||
    ''
  );
}

function handleWebchatMessage(event) {
  const id = extractConversationId(event.data);
  if (id) conversationId.value = id;
}

function ensureWebchatScript(scriptUrl) {
  return new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[src="${scriptUrl}"]`);
    if (existing) {
      resolve();
      return;
    }

    document
      .querySelectorAll('script[data-aptus-hub-webchat="true"]')
      .forEach(script => {
        if (script.src !== scriptUrl) script.remove();
      });

    const script = document.createElement('script');
    script.src = scriptUrl;
    script.async = true;
    script.dataset.aptusHubWebchat = 'true';
    script.onload = resolve;
    script.onerror = reject;
    document.body.appendChild(script);
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
      await ensureWebchatScript(response.data.script_url);
    }
  } catch (apiError) {
    error.value = hubErrorMessage(apiError);
  } finally {
    isLoading.value = false;
    isScriptLoading.value = false;
  }
}

async function sendFeedback() {
  if (!conversationId.value.trim() || !comment.value.trim()) return;
  isSending.value = true;
  error.value = '';

  try {
    await AptusHubAPI.feedback({
      conversation_id: conversationId.value.trim(),
      comment: comment.value.trim(),
    });
    comment.value = '';
    useAlert(t('HUB.TEST.FEEDBACK_SENT'));
  } catch (apiError) {
    error.value = hubErrorMessage(apiError);
  } finally {
    isSending.value = false;
  }
}

onMounted(() => {
  window.addEventListener('message', handleWebchatMessage);
  loadConfig();
});

onBeforeUnmount(() => {
  window.removeEventListener('message', handleWebchatMessage);
});
</script>

<template>
  <div class="flex-1 overflow-y-auto p-4">
    <div class="mb-4">
      <h2 class="text-lg font-semibold text-n-slate-12">
        {{ t('HUB.TEST.TITLE') }}
      </h2>
      <p class="text-sm text-n-slate-10">
        {{ t('HUB.TEST.SUBTITLE') }}
      </p>
    </div>

    <div
      v-if="error"
      class="mb-4 rounded-lg border border-n-ruby-5 bg-n-ruby-2 px-4 py-3 text-sm text-n-ruby-11"
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

      <div v-else class="grid gap-4 xl:grid-cols-[minmax(0,1fr)_360px]">
        <section
          class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 min-h-[440px] p-4"
        >
          <div class="flex items-center gap-2 text-sm text-n-slate-10">
            <i
              class="w-4 h-4"
              :class="
                isScriptLoading
                  ? 'i-lucide-loader-2 animate-spin'
                  : 'i-lucide-message-circle-play'
              "
            />
            {{ t('HUB.TEST.WEBCHAT') }}
          </div>
          <div
            class="mt-20 grid place-content-center text-center text-n-slate-9"
          >
            <i class="i-lucide-bot w-12 h-12 mx-auto mb-3" />
            <p class="text-sm">
              {{ t('HUB.TEST.WIDGET_READY') }}
            </p>
          </div>
        </section>

        <section
          class="rounded-lg border border-n-weak bg-white dark:bg-n-solid-2 p-4"
        >
          <h3 class="text-sm font-semibold text-n-slate-12 mb-3">
            {{ t('HUB.TEST.FEEDBACK') }}
          </h3>

          <label class="block text-xs font-medium text-n-slate-10 mb-1">
            {{ t('HUB.TEST.CONVERSATION_ID') }}
          </label>
          <input
            v-model="conversationId"
            class="w-full h-9 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12 mb-3"
            :placeholder="t('HUB.TEST.CONVERSATION_ID_PLACEHOLDER')"
          />

          <label class="block text-xs font-medium text-n-slate-10 mb-1">
            {{ t('HUB.TEST.COMMENT') }}
          </label>
          <textarea
            v-model="comment"
            rows="6"
            class="w-full rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12 resize-none"
          />

          <button
            class="mt-3 inline-flex items-center justify-center gap-2 h-9 px-3 rounded-lg text-sm font-medium bg-n-brand text-white hover:opacity-90 disabled:opacity-60 w-full"
            :disabled="isSending || !conversationId.trim() || !comment.trim()"
            @click="sendFeedback"
          >
            <i
              class="i-lucide-send w-4 h-4"
              :class="{ 'animate-pulse': isSending }"
            />
            {{ t('HUB.TEST.SEND_FEEDBACK') }}
          </button>
        </section>
      </div>
    </template>
  </div>
</template>
