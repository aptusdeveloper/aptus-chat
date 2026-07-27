<script setup>
import { ref, watch } from 'vue';
import Draggable from 'vuedraggable';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  activeTab: {
    type: String,
    default: wootConstants.ASSIGNEE_TYPE.ME,
  },
});

const emit = defineEmits(['chatTabChange', 'reorder']);

const localItems = ref([]);

watch(
  () => props.items,
  newItems => {
    localItems.value = [...newItems];
  },
  { immediate: true }
);

function onTabClick(key) {
  if (key !== props.activeTab) {
    emit('chatTabChange', key);
  }
}

function onDragEnd() {
  emit(
    'reorder',
    localItems.value.map(i => i.key)
  );
}

const keyboardEvents = {
  'Alt+KeyN': {
    action: () => {
      const current = localItems.value.findIndex(
        i => i.key === props.activeTab
      );
      const next = (current + 1) % localItems.value.length;
      const nextKey = localItems.value[next]?.key;
      if (nextKey && nextKey !== props.activeTab) {
        emit('chatTabChange', nextKey);
      }
    },
  },
};

useKeyboardEvents(keyboardEvents);
</script>

<template>
  <div class="flex border-b border-b-n-weak w-full -mt-1 h-10 items-end px-3">
    <Draggable
      v-model="localItems"
      item-key="key"
      :animation="200"
      class="flex items-end h-full"
      ghost-class="opacity-30"
      @end="onDragEnd"
    >
      <template #item="{ element, index }">
        <button
          class="flex items-center flex-shrink-0 select-none relative pb-2.5 text-button cursor-grab active:cursor-grabbing after:absolute after:bottom-px after:left-0 after:right-0 after:h-[2px] after:rounded-full after:transition-all after:duration-200"
          :class="[
            index < localItems.length - 1 ? 'mr-4' : '',
            activeTab === element.key
              ? 'text-n-blue-11 after:bg-n-brand after:opacity-100'
              : 'text-n-slate-11 after:bg-transparent after:opacity-0',
          ]"
          @click="onTabClick(element.key)"
          @contextmenu.prevent
        >
          {{ element.name }}
          <span
            class="rounded-full h-5 flex items-center justify-center text-xs font-medium ml-1 px-1.5 min-w-[20px]"
            :class="[
              activeTab === element.key
                ? 'bg-n-blue-3 text-n-blue-11'
                : 'bg-n-alpha-1 text-n-slate-10',
            ]"
          >
            {{ element.count }}
          </span>
        </button>
      </template>
    </Draggable>
  </div>
</template>
