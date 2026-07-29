<script setup>
/**
 * This component handles parsing and sending WhatsApp message templates.
 * It works as follows:
 * 1. Displays the template text with variable placeholders.
 * 2. Generates input fields for each variable in the template.
 * 3. Validates that all variables are filled before sending.
 * 4. Replaces placeholders with user-provided values.
 * 5. Emits events to send the processed message or reset the template.
 */
import { ref, computed, onMounted, watch } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { requiredIf } from '@vuelidate/validators';
import { useI18n } from 'vue-i18n';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import WhatsAppMessagePreviewBubble from 'dashboard/components-next/whatsapp/WhatsAppMessagePreviewBubble.vue';
import { useAlert } from 'dashboard/composables';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import {
  buildTemplateParameters,
  allKeysRequired,
  replaceTemplateVariables,
  processVariable,
  DEFAULT_LANGUAGE,
  DEFAULT_CATEGORY,
  COMPONENT_TYPES,
  MEDIA_FORMATS,
  findComponentByType,
  isPublicHttpsMediaUrl,
} from 'dashboard/helper/templateHelper';

const props = defineProps({
  template: {
    type: Object,
    default: () => ({}),
    validator: value => {
      if (!value || typeof value !== 'object') return false;
      if (!value.components || !Array.isArray(value.components)) return false;
      return true;
    },
  },
});

const emit = defineEmits(['sendMessage', 'resetTemplate', 'back']);

const { t } = useI18n();

const processedParams = ref({});

const languageLabel = computed(() => {
  return `${t('WHATSAPP_TEMPLATES.PARSER.LANGUAGE')}: ${props.template.language || DEFAULT_LANGUAGE}`;
});

const categoryLabel = computed(() => {
  return `${t('WHATSAPP_TEMPLATES.PARSER.CATEGORY')}: ${props.template.category || DEFAULT_CATEGORY}`;
});

const headerComponent = computed(() => {
  return findComponentByType(props.template, COMPONENT_TYPES.HEADER);
});

const bodyComponent = computed(() => {
  return findComponentByType(props.template, COMPONENT_TYPES.BODY);
});

const bodyText = computed(() => {
  return bodyComponent.value?.text || '';
});

const hasMediaHeader = computed(() =>
  MEDIA_FORMATS.includes(headerComponent.value?.format)
);

// A TEXT header may itself carry a single {{1}} variable (Meta allows at
// most one, but we handle it generically like body variables).
const headerVariableKeys = computed(() => {
  if (headerComponent.value?.format !== 'TEXT') return [];
  const matches = headerComponent.value.text?.match(/{{([^}]+)}}/g) || [];
  return matches.map(processVariable);
});
const hasHeaderVariable = computed(() => headerVariableKeys.value.length > 0);

const renderedHeaderText = computed(() => {
  if (headerComponent.value?.format !== 'TEXT') return '';
  return replaceTemplateVariables(
    headerComponent.value.text || '',
    processedParams.value,
    'header'
  );
});

const footerComponent = computed(() =>
  findComponentByType(props.template, COMPONENT_TYPES.FOOTER)
);
const footerText = computed(() => footerComponent.value?.text || '');

const buttonsComponent = computed(() =>
  findComponentByType(props.template, COMPONENT_TYPES.BUTTONS)
);

// Button labels never change based on the parameter the agent fills in
// (e.g. a URL button's visible text stays the same regardless of the
// dynamic suffix), so this is safe to use both for the live preview and
// for what gets persisted alongside the sent message.
const templateButtons = computed(
  () =>
    buttonsComponent.value?.buttons?.map(button => ({
      type: button.type,
      text: button.text,
    })) || []
);

const formatType = computed(() => {
  const format = headerComponent.value?.format;
  return format ? format.charAt(0) + format.slice(1).toLowerCase() : '';
});

const isDocumentTemplate = computed(() => {
  return headerComponent.value?.format?.toLowerCase() === 'document';
});

const carouselComponent = computed(() =>
  findComponentByType(props.template, COMPONENT_TYPES.CAROUSEL)
);
const isCarouselTemplate = computed(() => !!carouselComponent.value);
const carouselCardCount = computed(
  () => carouselComponent.value?.cards?.length || 0
);
const carouselReferenceCard = computed(
  () => carouselComponent.value?.cards?.[0]
);
const carouselHeaderComponent = computed(() =>
  carouselReferenceCard.value?.components?.find(
    component => component.type === COMPONENT_TYPES.HEADER
  )
);
const carouselHasMediaHeader = computed(() =>
  MEDIA_FORMATS.includes(carouselHeaderComponent.value?.format)
);
const carouselHeaderFormatLabel = computed(() => {
  const format = carouselHeaderComponent.value?.format;
  return format ? format.charAt(0) + format.slice(1).toLowerCase() : '';
});
const carouselMediaAccept = computed(() => {
  return carouselHeaderComponent.value?.format === 'VIDEO'
    ? 'video/*'
    : 'image/*';
});

const activeCardIndex = ref(0);
const uploadingCardIndex = ref(null);
const cardFileInputs = ref([]);
const cardMediaModes = ref([]);

const cardTabs = computed(() =>
  Array.from({ length: carouselCardCount.value }, (_, index) => ({
    label: t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.CARD_LABEL', {
      index: index + 1,
    }),
    index,
  }))
);

const hasVariables = computed(() => {
  return bodyText.value?.match(/{{([^}]+)}}/g) !== null;
});

const renderedTemplate = computed(() => {
  return replaceTemplateVariables(bodyText.value, processedParams.value);
});

const isFormInvalid = computed(() => {
  if (
    !hasVariables.value &&
    !hasMediaHeader.value &&
    !hasHeaderVariable.value &&
    !isCarouselTemplate.value
  ) {
    return false;
  }

  if (hasMediaHeader.value && !processedParams.value.header?.media_url) {
    return true;
  }

  if (hasHeaderVariable.value) {
    const hasEmptyHeaderVariable = headerVariableKeys.value.some(
      key => !processedParams.value.header?.[key]
    );
    if (hasEmptyHeaderVariable) return true;
  }

  if (hasVariables.value && processedParams.value.body) {
    const hasEmptyBodyVariable = Object.values(processedParams.value.body).some(
      value => !value
    );
    if (hasEmptyBodyVariable) return true;
  }

  if (processedParams.value.buttons) {
    const hasEmptyButtonParameter = processedParams.value.buttons.some(
      button => !button.parameter
    );
    if (hasEmptyButtonParameter) return true;
  }

  if (isCarouselTemplate.value) {
    const cards = processedParams.value.cards || [];
    const hasIncompleteCard = cards.some(card => {
      if (card.header && !isPublicHttpsMediaUrl(card.header.media_url)) {
        return true;
      }
      if (card.buttons) {
        return card.buttons.some(button => !button.parameter);
      }
      return false;
    });
    if (hasIncompleteCard) return true;
  }

  return false;
});

const v$ = useVuelidate(
  {
    processedParams: {
      requiredIfKeysPresent: requiredIf(hasVariables),
      allKeysRequired,
    },
  },
  { processedParams }
);

const initializeTemplateParameters = () => {
  processedParams.value = buildTemplateParameters(
    props.template,
    hasMediaHeader.value
  );
  cardMediaModes.value = Array.from(
    { length: carouselCardCount.value },
    () => 'upload'
  );
};

const updateMediaUrl = value => {
  processedParams.value.header ??= {};
  processedParams.value.header.media_url = value;
};

const updateMediaName = value => {
  processedParams.value.header ??= {};
  processedParams.value.header.media_name = value;
};

const handleCardTabChanged = tab => {
  activeCardIndex.value = tab.index;
};

const triggerCardFileInput = cardIndex => {
  cardFileInputs.value[cardIndex]?.click();
};

const setCardMediaMode = (cardIndex, mode) => {
  cardMediaModes.value[cardIndex] = mode;
};

const updateCardMediaUrl = (cardIndex, value) => {
  processedParams.value.cards[cardIndex].header ??= {};
  processedParams.value.cards[cardIndex].header.media_url = value.trim();
};

const isCardMediaUrlInvalid = card => {
  const value = card.header?.media_url;
  return !!value && !isPublicHttpsMediaUrl(value);
};

const uploadCardMedia = async (cardIndex, file) => {
  if (!file) return;

  uploadingCardIndex.value = cardIndex;
  try {
    const { fileUrl } = await uploadFile(file);
    processedParams.value.cards[cardIndex].header ??= {};
    processedParams.value.cards[cardIndex].header.media_url = fileUrl;
    cardMediaModes.value[cardIndex] = 'upload';

    if (!isPublicHttpsMediaUrl(fileUrl)) {
      useAlert(t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.NON_PUBLIC_UPLOAD'));
    }
  } catch (error) {
    useAlert(t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.MEDIA_UPLOAD_ERROR'));
  } finally {
    uploadingCardIndex.value = null;
  }
};

const handleCardFileChange = (cardIndex, event) => {
  const file = event.target.files?.[0];
  uploadCardMedia(cardIndex, file);
  // Reset so selecting the same file again still fires a change event
  event.target.value = null;
};

const sendMessage = () => {
  v$.value.$touch();
  if (v$.value.$invalid || isFormInvalid.value) return;

  const { name, category, language, namespace } = props.template;

  const contentAttributes = {};
  if (renderedHeaderText.value) {
    contentAttributes.template_header = renderedHeaderText.value;
  }
  if (footerText.value) {
    contentAttributes.template_footer = footerText.value;
  }
  if (templateButtons.value.length) {
    contentAttributes.template_buttons = templateButtons.value;
  }

  const payload = {
    message: renderedTemplate.value,
    templateParams: {
      name,
      category,
      language,
      namespace,
      processed_params: processedParams.value,
    },
    ...(Object.keys(contentAttributes).length && { contentAttributes }),
  };
  emit('sendMessage', payload);
};

const resetTemplate = () => {
  emit('resetTemplate');
};

const goBack = () => {
  emit('back');
};

onMounted(initializeTemplateParameters);

watch(
  () => props.template,
  () => {
    initializeTemplateParameters();
    activeCardIndex.value = 0;
    v$.value.$reset();
  },
  { deep: true }
);

defineExpose({
  processedParams,
  hasVariables,
  hasMediaHeader,
  isDocumentTemplate,
  headerComponent,
  renderedTemplate,
  v$,
  updateMediaUrl,
  updateMediaName,
  updateCardMediaUrl,
  isCarouselTemplate,
  sendMessage,
  resetTemplate,
  goBack,
});
</script>

<template>
  <div>
    <div class="flex flex-col gap-4 p-4 mb-4 rounded-lg bg-n-alpha-black2">
      <div class="flex justify-between items-center">
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ template.name }}
        </h3>
        <span class="text-xs text-n-slate-11">
          {{ languageLabel }}
        </span>
      </div>

      <div v-if="!isCarouselTemplate" class="flex justify-center">
        <WhatsAppMessagePreviewBubble
          :header-text="renderedHeaderText"
          :header-format="headerComponent?.format"
          :body-text="renderedTemplate"
          :footer-text="footerText"
          :buttons="templateButtons"
        />
      </div>

      <div class="text-xs text-n-slate-11">
        {{ categoryLabel }}
      </div>
    </div>

    <div
      v-if="
        hasVariables ||
        hasMediaHeader ||
        hasHeaderVariable ||
        isCarouselTemplate
      "
    >
      <div v-if="hasMediaHeader" class="mb-4">
        <p class="mb-2.5 text-sm font-semibold">
          {{
            $t('WHATSAPP_TEMPLATES.PARSER.MEDIA_HEADER_LABEL', {
              type: formatType,
            }) || `${formatType} Header`
          }}
        </p>
        <div class="flex items-center mb-2.5">
          <Input
            :model-value="processedParams.header?.media_url || ''"
            type="url"
            class="flex-1"
            :placeholder="
              t('WHATSAPP_TEMPLATES.PARSER.MEDIA_URL_LABEL', {
                type: formatType,
              })
            "
            @update:model-value="updateMediaUrl"
          />
        </div>
        <div v-if="isDocumentTemplate" class="flex items-center mb-2.5">
          <Input
            :model-value="processedParams.header?.media_name || ''"
            type="text"
            class="flex-1"
            :placeholder="
              t('WHATSAPP_TEMPLATES.PARSER.DOCUMENT_NAME_PLACEHOLDER')
            "
            @update:model-value="updateMediaName"
          />
        </div>
      </div>

      <!-- Header Variable Section -->
      <div v-if="hasHeaderVariable" class="mb-4">
        <p class="mb-2.5 text-sm font-semibold">
          {{ t('WHATSAPP_TEMPLATES.PARSER.HEADER_VARIABLES_LABEL') }}
        </p>
        <div
          v-for="key in headerVariableKeys"
          :key="`header-${key}`"
          class="flex items-center mb-2.5"
        >
          <Input
            v-model="processedParams.header[key]"
            type="text"
            class="flex-1"
            :placeholder="
              t('WHATSAPP_TEMPLATES.PARSER.VARIABLE_PLACEHOLDER', {
                variable: key,
              })
            "
          />
        </div>
      </div>

      <!-- Body Variables Section -->
      <div v-if="processedParams.body">
        <p class="mb-2.5 text-sm font-semibold">
          {{ $t('WHATSAPP_TEMPLATES.PARSER.VARIABLES_LABEL') }}
        </p>
        <div
          v-for="(variable, key) in processedParams.body"
          :key="`body-${key}`"
          class="flex items-center mb-2.5"
        >
          <Input
            v-model="processedParams.body[key]"
            type="text"
            class="flex-1"
            :placeholder="
              t('WHATSAPP_TEMPLATES.PARSER.VARIABLE_PLACEHOLDER', {
                variable: key,
              })
            "
          />
        </div>
      </div>

      <!-- Button Variables Section -->
      <div v-if="processedParams.buttons">
        <p class="mb-2.5 text-sm font-semibold">
          {{ t('WHATSAPP_TEMPLATES.PARSER.BUTTON_PARAMETERS') }}
        </p>
        <div
          v-for="(button, index) in processedParams.buttons"
          :key="`button-${index}`"
          class="flex items-center mb-2.5"
        >
          <Input
            v-model="processedParams.buttons[index].parameter"
            type="text"
            class="flex-1"
            :placeholder="t('WHATSAPP_TEMPLATES.PARSER.BUTTON_PARAMETER')"
          />
        </div>
      </div>
      <!-- Carousel Cards Section -->
      <div v-if="isCarouselTemplate" class="mb-4">
        <div class="flex justify-between items-center mb-2.5">
          <p class="text-sm font-semibold">
            {{ t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.CARDS_LABEL') }}
          </p>
          <span class="text-xs text-n-slate-11">
            {{
              t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.CARD_PROGRESS', {
                current: activeCardIndex + 1,
                total: carouselCardCount,
              })
            }}
          </span>
        </div>

        <TabBar
          :tabs="cardTabs"
          :initial-active-tab="activeCardIndex"
          class="mb-3"
          @tab-changed="handleCardTabChanged"
        />

        <div
          v-for="(card, cardIndex) in processedParams.cards"
          v-show="cardIndex === activeCardIndex"
          :key="`card-${cardIndex}`"
        >
          <div v-if="carouselHasMediaHeader" class="mb-2.5">
            <p class="mb-2 text-xs text-n-slate-11">
              {{
                t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.MEDIA_LABEL', {
                  type: carouselHeaderFormatLabel,
                })
              }}
            </p>
            <div class="flex gap-2 mb-2">
              <Button
                :label="t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.UPLOAD_MODE')"
                sm
                :slate="cardMediaModes[cardIndex] !== 'upload'"
                :faded="cardMediaModes[cardIndex] !== 'upload'"
                @click="setCardMediaMode(cardIndex, 'upload')"
              />
              <Button
                :label="t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.URL_MODE')"
                sm
                :slate="cardMediaModes[cardIndex] !== 'url'"
                :faded="cardMediaModes[cardIndex] !== 'url'"
                @click="setCardMediaMode(cardIndex, 'url')"
              />
            </div>
            <div
              v-if="cardMediaModes[cardIndex] === 'upload'"
              class="flex gap-2 items-center"
            >
              <Button
                :label="
                  card.header?.media_url
                    ? t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.CHANGE_MEDIA')
                    : t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.UPLOAD_MEDIA')
                "
                slate
                faded
                sm
                :is-loading="uploadingCardIndex === cardIndex"
                @click="triggerCardFileInput(cardIndex)"
              />
              <span
                v-if="card.header?.media_url"
                class="text-xs truncate text-n-slate-11"
              >
                {{ card.header.media_url }}
              </span>
            </div>
            <Input
              v-else
              :model-value="card.header?.media_url || ''"
              type="url"
              :placeholder="
                t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.URL_PLACEHOLDER')
              "
              @update:model-value="updateCardMediaUrl(cardIndex, $event)"
            />
            <p class="mt-2 text-xs text-n-slate-11">
              {{ t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.PUBLIC_URL_HINT') }}
            </p>
            <p
              v-if="isCardMediaUrlInvalid(card)"
              class="mt-1 text-xs text-n-ruby-9"
            >
              {{ t('WHATSAPP_TEMPLATES.PARSER.CAROUSEL.INVALID_URL') }}
            </p>
            <input
              :ref="el => (cardFileInputs[cardIndex] = el)"
              type="file"
              class="hidden"
              :accept="carouselMediaAccept"
              @change="handleCardFileChange(cardIndex, $event)"
            />
          </div>

          <div v-if="card.buttons?.length">
            <p class="mb-2.5 text-xs text-n-slate-11">
              {{ t('WHATSAPP_TEMPLATES.PARSER.BUTTON_PARAMETERS') }}
            </p>
            <div
              v-for="(button, buttonIndex) in card.buttons"
              :key="`card-${cardIndex}-button-${buttonIndex}`"
              class="flex items-center mb-2.5"
            >
              <Input
                v-if="button"
                v-model="card.buttons[buttonIndex].parameter"
                type="text"
                class="flex-1"
                :placeholder="t('WHATSAPP_TEMPLATES.PARSER.BUTTON_PARAMETER')"
              />
            </div>
          </div>
        </div>
      </div>

      <p
        v-if="v$.$dirty && v$.$invalid"
        class="p-2.5 text-center rounded-md bg-n-ruby-9/20 text-n-ruby-9"
      >
        {{ $t('WHATSAPP_TEMPLATES.PARSER.FORM_ERROR_MESSAGE') }}
      </p>
    </div>

    <slot
      name="actions"
      :send-message="sendMessage"
      :reset-template="resetTemplate"
      :go-back="goBack"
      :is-valid="!v$.$invalid"
      :disabled="isFormInvalid"
    />
  </div>
</template>
