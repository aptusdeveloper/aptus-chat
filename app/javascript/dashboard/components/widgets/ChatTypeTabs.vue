<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
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

const emit = defineEmits(['chatTabChange', 'setDefault', 'reorder']);

const { t } = useI18n();

const localItems = ref([]);
const contextMenu = ref({
  visible: false,
  x: 0,
  y: 0,
  key: null,
  isDefault: false,
});

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

function onContextMenu(event, key, index) {
  event.preventDefault();
  contextMenu.value = {
    visible: true,
    x: event.clientX,
    y: event.clientY,
    key,
    isDefault: index === 0,
  };
}

function setAsDefault() {
  emit('setDefault', contextMenu.value.key);
  contextMenu.value.visible = false;
}

function closeContextMenu() {
  contextMenu.value.visible = false;
}

function onMove(evt) {
  if (evt.draggedContext.index === 0) return false;
  if (evt.relatedContext.index === 0) return false;
  return true;
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
      :move="onMove"
      class="flex items-end h-full"
      ghost-class="opacity-30"
      @end="onDragEnd"
    >
      <template #item="{ element, index }">
        <button
          class="flex items-center flex-shrink-0 select-none relative pb-2.5 text-button after:absolute after:bottom-px after:left-0 after:right-0 after:h-[2px] after:rounded-full after:transition-all after:duration-200"
          :class="[
            index < localItems.length - 1 ? 'mr-4' : '',
            index === 0
              ? 'cursor-pointer'
              : 'cursor-grab active:cursor-grabbing',
            activeTab === element.key
              ? 'text-n-blue-11 after:bg-n-brand after:opacity-100'
              : 'text-n-slate-11 after:bg-transparent after:opacity-0',
          ]"
          @click="onTabClick(element.key)"
          @contextmenu="onContextMenu($event, element.key, index)"
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

    <Teleport to="body">
      <div
        v-if="contextMenu.visible"
        class="fixed inset-0 z-50"
        @click="closeContextMenu"
        @contextmenu.prevent="closeContextMenu"
      >
        <div
          class="absolute bg-white dark:bg-n-solid-2 rounded-lg shadow-lg border border-n-weak py-1 min-w-[160px]"
          :style="{ top: contextMenu.y + 'px', left: contextMenu.x + 'px' }"
          @click.stop
        >
          <button
            v-if="!contextMenu.isDefault"
            class="w-full text-left px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-1 transition-colors"
            @click="setAsDefault"
          >
            {{ t('CHAT_LIST.ASSIGNEE_TYPE_TABS_CONTEXT_MENU.SET_AS_DEFAULT') }}
          </button>
          <span
            v-else
            class="block px-3 py-2 text-sm text-n-slate-9 cursor-default"
          >
            {{ t('CHAT_LIST.ASSIGNEE_TYPE_TABS_CONTEXT_MENU.IS_DEFAULT') }}
          </span>
        </div>
      </div>
    </Teleport>
  </div>
</template>
