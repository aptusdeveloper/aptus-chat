<script setup>
import { computed } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { getButtonTypeMeta } from 'dashboard/helper/templateHelper';

const props = defineProps({
  headerText: { type: String, default: '' },
  headerFormat: { type: String, default: '' },
  bodyText: { type: String, default: '' },
  footerText: { type: String, default: '' },
  buttons: { type: Array, default: () => [] },
  timestamp: { type: String, default: '' },
});

const MEDIA_HEADER_ICONS = {
  IMAGE: 'i-lucide-image',
  VIDEO: 'i-lucide-video',
  DOCUMENT: 'i-lucide-file-text',
};

const mediaHeaderIcon = computed(
  () => MEDIA_HEADER_ICONS[props.headerFormat] || 'i-lucide-file'
);

const isMediaHeader = computed(() =>
  Object.keys(MEDIA_HEADER_ICONS).includes(props.headerFormat)
);

const displayTimestamp = computed(() => {
  if (props.timestamp) return props.timestamp;
  return new Date().toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  });
});

const buttonMeta = button => getButtonTypeMeta(button.type);
</script>

<template>
  <div
    class="w-full max-w-[280px] rounded-lg bg-[#1a2329] text-[#e9edef] shadow-md overflow-hidden"
  >
    <div class="px-3 pt-2.5 pb-3">
      <div
        v-if="isMediaHeader"
        class="flex gap-2 items-center px-2.5 py-4 mb-2 rounded bg-black/20 text-[#8696a0]"
      >
        <Icon :icon="mediaHeaderIcon" class="size-5 shrink-0" />
        <span class="text-xs">{{ headerFormat }}</span>
      </div>

      <div class="flex gap-2 justify-between items-start">
        <p
          v-if="headerText && !isMediaHeader"
          class="text-[0.9rem] font-semibold leading-snug break-words"
        >
          {{ headerText }}
        </p>
        <span
          v-if="!bodyText && !headerText"
          class="text-xs text-[#8696a0] whitespace-nowrap"
        >
          {{ displayTimestamp }}
        </span>
      </div>

      <p
        v-if="bodyText"
        class="text-[0.9rem] leading-snug whitespace-pre-wrap break-words"
      >
        {{ bodyText }}
      </p>

      <p
        v-if="footerText"
        class="mt-1 text-xs text-[#8696a0] leading-snug break-words"
      >
        {{ footerText }}
      </p>

      <div class="flex justify-end mt-1">
        <span class="text-[0.65rem] text-[#8696a0]">{{
          displayTimestamp
        }}</span>
      </div>
    </div>

    <div v-if="buttons.length" class="border-t border-white/10">
      <div
        v-for="(button, index) in buttons"
        :key="`${index}-${button.text}`"
        class="flex gap-2 justify-center items-center py-2.5 text-sm font-medium text-[#00a5f4]"
        :class="{ 'border-t border-white/10': index > 0 }"
      >
        <Icon
          v-if="buttonMeta(button)"
          :icon="buttonMeta(button).icon"
          class="size-3.5 shrink-0"
        />
        <span class="truncate">{{ button.text }}</span>
      </div>
    </div>
  </div>
</template>
