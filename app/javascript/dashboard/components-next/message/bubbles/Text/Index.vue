<script setup>
import { computed, ref } from 'vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import FormattedContent from './FormattedContent.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { getButtonTypeMeta } from 'dashboard/helper/templateHelper';

const {
  id,
  conversationId,
  content,
  attachments,
  contentAttributes,
  messageType,
} = useMessageContext();

const store = useStore();
const { t } = useI18n();

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const renderOriginal = ref(false);

const renderContent = computed(() => {
  if (renderOriginal.value) {
    return content.value;
  }

  if (hasTranslations.value) {
    return translationContent.value;
  }

  return content.value;
});

const isTemplate = computed(() => {
  return messageType.value === MESSAGE_TYPES.TEMPLATE;
});

const isEmpty = computed(() => {
  return !content.value && !attachments.value?.length;
});

// Template messages read as a compact card (like the template preview),
// so they shouldn't stretch as wide as a regular long text bubble.
const isWhatsappTemplateMessage = computed(() => {
  return !!(
    contentAttributes.value.templateHeader ||
    contentAttributes.value.templateFooter ||
    contentAttributes.value.templateButtons?.length
  );
});

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};

const buttonMeta = button => getButtonTypeMeta(button.type);

// Lets an agent click a template's own button to simulate the contact
// tapping it on WhatsApp: sends a new outgoing message with the button's
// label, replying to the template message it belongs to.
const handleButtonClick = async button => {
  try {
    await store.dispatch('createPendingMessageAndSend', {
      conversationId: conversationId.value,
      message: button.text,
      contentAttributes: { in_reply_to: id.value },
    });
  } catch (error) {
    useAlert(t('CONVERSATION.MESSAGE_ERROR'));
  }
};
</script>

<template>
  <BaseBubble
    class="px-4 py-3"
    :class="{ 'whatsapp-template-bubble': isWhatsappTemplateMessage }"
    data-bubble-name="text"
  >
    <div class="gap-3 flex flex-col">
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <div class="flex flex-col gap-0.5">
        <div
          v-if="contentAttributes.templateHeader"
          class="font-semibold text-n-slate-12"
        >
          {{ contentAttributes.templateHeader }}
        </div>
        <FormattedContent v-if="renderContent" :content="renderContent" />
        <div
          v-if="contentAttributes.templateFooter"
          class="text-xs text-n-slate-11"
        >
          {{ contentAttributes.templateFooter }}
        </div>
      </div>
      <TranslationToggle
        v-if="hasTranslations"
        class="-mt-3"
        :showing-original="renderOriginal"
        @toggle="handleSeeOriginal"
      />
      <AttachmentChips :attachments="attachments" class="gap-2" />
      <template v-if="isTemplate">
        <div
          v-if="contentAttributes.submittedEmail"
          class="px-2 py-1 rounded-lg bg-n-alpha-3"
        >
          {{ contentAttributes.submittedEmail }}
        </div>
      </template>
      <div
        v-if="contentAttributes.templateButtons?.length"
        class="flex flex-col mt-1 whatsapp-template-buttons"
      >
        <button
          v-for="(button, index) in contentAttributes.templateButtons"
          :key="`${index}-${button.text}`"
          type="button"
          class="flex gap-2 justify-center items-center py-2.5 px-4 w-full text-sm font-medium transition-colors text-n-blue-11 hover:text-n-blue-12"
          @click="handleButtonClick(button)"
        >
          <Icon
            v-if="buttonMeta(button)"
            :icon="buttonMeta(button).icon"
            class="size-3.5 shrink-0"
          />
          <span class="truncate">{{ button.text }}</span>
        </button>
      </div>
    </div>
  </BaseBubble>
</template>

<style>
p:last-child {
  margin-bottom: 0;
}
</style>

<style scoped>
/* Hand-written CSS (not Tailwind utilities) so these two rules don't
   depend on the JIT scanner picking up dynamically-toggled classes. */
.whatsapp-template-bubble {
  width: 100%;
  max-width: 18rem;
}

.whatsapp-template-buttons {
  margin-left: -1rem;
  margin-right: -1rem;
  border-top: 1px solid rgba(255, 255, 255, 0.15);
  border-bottom: 1px solid rgba(255, 255, 255, 0.15);
}

.whatsapp-template-buttons > button {
  border-radius: 0;
}

.whatsapp-template-buttons > button + button {
  border-top: 1px solid rgba(255, 255, 255, 0.15);
}
</style>
