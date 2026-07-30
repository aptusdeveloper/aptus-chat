<script setup>
import { reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  days: {
    // [{ value: Number, label: String }] - the other days available as copy targets
    type: Array,
    required: true,
  },
});

const emit = defineEmits(['apply']);
const { t } = useI18n();

const selected = reactive({});

function reset() {
  props.days.forEach(day => {
    selected[day.value] = false;
  });
}

function apply(hide) {
  const targets = props.days
    .filter(day => selected[day.value])
    .map(day => day.value);
  if (targets.length) emit('apply', targets);
  hide();
}
</script>

<template>
  <Popover align="start" @show="reset">
    <Button
      slate
      outline
      xs
      icon="i-lucide-copy"
      :label="t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.COPY_TO')"
      :disabled="!days.length"
    />
    <template #content="{ hide }">
      <div class="p-3 w-56 flex flex-col gap-1">
        <p class="text-xs font-medium text-n-slate-11 px-1 pb-1">
          {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.COPY_TO_HINT') }}
        </p>
        <label
          v-for="day in days"
          :key="day.value"
          class="flex items-center gap-2 px-1 py-1.5 rounded-md hover:bg-n-alpha-2 cursor-pointer"
        >
          <Checkbox v-model="selected[day.value]" />
          <span class="text-sm text-n-slate-12">{{ day.label }}</span>
        </label>
        <Button
          sm
          class="mt-2"
          :label="t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.COPY_APPLY')"
          @click="apply(hide)"
        />
      </div>
    </template>
  </Popover>
</template>
