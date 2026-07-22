<script setup>
import { computed } from 'vue';

const props = defineProps({
  stages: {
    type: Array,
    default: () => [],
  },
  currentStageId: {
    type: String,
    default: null,
  },
});

const currentIndex = computed(() =>
  props.stages.findIndex(stage => stage.id === props.currentStageId)
);

const currentStage = computed(() =>
  currentIndex.value === -1 ? null : props.stages[currentIndex.value]
);

// Picks readable text color (black or white) for an arbitrary hex background,
// since stage.color is a free color-picker value, not a design-system token.
function readableTextColor(hex) {
  if (!hex) return '#0B1C2C';
  const value = hex.replace('#', '');
  const r = parseInt(value.substring(0, 2), 16);
  const g = parseInt(value.substring(2, 4), 16);
  const b = parseInt(value.substring(4, 6), 16);
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  return luminance > 0.6 ? '#0B1C2C' : '#FFFFFF';
}

const badgeStyle = computed(() => {
  if (!currentStage.value) return {};
  return {
    backgroundColor: currentStage.value.color,
    color: readableTextColor(currentStage.value.color),
  };
});

function segmentStyle(stage, index) {
  const isReached = currentIndex.value !== -1 && index <= currentIndex.value;
  return isReached ? { backgroundColor: stage.color } : {};
}

function segmentClass(index) {
  const isReached = currentIndex.value !== -1 && index <= currentIndex.value;
  return isReached ? '' : 'bg-n-slate-4';
}
</script>

<template>
  <div class="flex flex-col gap-2">
    <span
      v-if="currentStage"
      class="inline-flex w-fit items-center px-2 py-0.5 rounded-md text-xs font-medium"
      :style="badgeStyle"
    >
      {{ currentStage.name }}
    </span>
    <div class="flex items-center gap-1 w-full">
      <div
        v-for="(stage, index) in stages"
        :key="stage.id"
        class="h-1.5 flex-1 rounded-full transition-colors"
        :class="segmentClass(index)"
        :style="segmentStyle(stage, index)"
        :title="stage.name"
      />
    </div>
  </div>
</template>
