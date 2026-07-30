<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import AgendaDayCopyPopover from './AgendaDayCopyPopover.vue';

const props = defineProps({
  professionalId: {
    type: String,
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();

// Displayed Monday first, Sunday last (day_of_week keeps the 0=Sunday..6=Saturday value used by the backend)
const DISPLAY_ORDER = [1, 2, 3, 4, 5, 6, 0];

function dayLabel(dayOfWeek) {
  return t(`HUB.AGENDA.PROFESSIONALS.AVAILABILITY.DAYS.${dayOfWeek}`);
}

function defaultRange() {
  return { start: '09:00', end: '18:00' };
}

const days = ref([]);
const baselineSnapshot = ref('');
const isLoading = ref(false);
const isSaving = ref(false);

function hydrate() {
  const weeklyBlocks = store.getters['agenda/availabilitiesForProfessional'](
    props.professionalId
  ).filter(a => !a.date);

  const rangesByDay = new Map();
  weeklyBlocks.forEach(block => {
    const list = rangesByDay.get(block.day_of_week) || [];
    list.push({
      start: `${String(block.start_hour).padStart(2, '0')}:${String(block.start_minutes).padStart(2, '0')}`,
      end: `${String(block.end_hour).padStart(2, '0')}:${String(block.end_minutes).padStart(2, '0')}`,
    });
    rangesByDay.set(block.day_of_week, list);
  });

  days.value = DISPLAY_ORDER.map(dayOfWeek => {
    const ranges = rangesByDay.get(dayOfWeek);
    return {
      dayOfWeek,
      active: !!ranges?.length,
      ranges: ranges?.length ? ranges : [defaultRange()],
    };
  });
  baselineSnapshot.value = JSON.stringify(days.value);
}

const isDirty = computed(
  () => JSON.stringify(days.value) !== baselineSnapshot.value
);

function otherDaysFor(dayOfWeek) {
  return days.value
    .filter(day => day.dayOfWeek !== dayOfWeek)
    .map(day => ({ value: day.dayOfWeek, label: dayLabel(day.dayOfWeek) }));
}

function addRange(day) {
  const last = day.ranges[day.ranges.length - 1];
  day.ranges.push({ start: last?.end || '09:00', end: '18:00' });
}

function removeRange(day, index) {
  day.ranges.splice(index, 1);
}

function applyCopy(sourceDay, targetDayValues) {
  const clonedRanges = sourceDay.ranges.map(range => ({ ...range }));
  targetDayValues.forEach(dayOfWeek => {
    const target = days.value.find(day => day.dayOfWeek === dayOfWeek);
    if (!target) return;
    target.active = true;
    target.ranges = clonedRanges.map(range => ({ ...range }));
  });
}

function isRangeInvalid(range) {
  return !range.start || !range.end || range.start >= range.end;
}

const hasInvalidRange = computed(() =>
  days.value.some(day => day.active && day.ranges.some(isRangeInvalid))
);

function buildWeeklyBlocksPayload() {
  return days.value
    .filter(day => day.active)
    .flatMap(day =>
      day.ranges.map(range => {
        const [startHour, startMinutes] = range.start.split(':').map(Number);
        const [endHour, endMinutes] = range.end.split(':').map(Number);
        return {
          day_of_week: day.dayOfWeek,
          start_hour: startHour,
          start_minutes: startMinutes,
          end_hour: endHour,
          end_minutes: endMinutes,
        };
      })
    );
}

async function save() {
  if (hasInvalidRange.value) return;
  isSaving.value = true;
  try {
    await store.dispatch('agenda/replaceWeeklyAvailability', {
      professionalId: props.professionalId,
      weeklyBlocks: buildWeeklyBlocksPayload(),
    });
    baselineSnapshot.value = JSON.stringify(days.value);
    useAlert(t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
}

function discard() {
  hydrate();
}

watch(
  () => props.professionalId,
  async () => {
    isLoading.value = true;
    await store.dispatch('agenda/fetchAvailabilities', props.professionalId);
    hydrate();
    isLoading.value = false;
  }
);

onMounted(async () => {
  isLoading.value = true;
  await store.dispatch('agenda/fetchAvailabilities', props.professionalId);
  hydrate();
  isLoading.value = false;
});
</script>

<template>
  <div>
    <div v-if="isLoading" class="text-sm text-n-slate-10 py-2">
      {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.LOADING') }}
    </div>
    <div v-else class="flex flex-col divide-y divide-n-weak">
      <div
        v-for="day in days"
        :key="day.dayOfWeek"
        class="flex flex-col sm:flex-row sm:items-start gap-3 py-3"
      >
        <div class="flex items-center gap-2 sm:w-36 shrink-0 pt-1.5">
          <Switch v-model="day.active" />
          <span class="text-sm font-medium text-n-slate-12">
            {{ dayLabel(day.dayOfWeek) }}
          </span>
        </div>

        <div v-if="!day.active" class="flex items-center pt-1.5">
          <span class="text-sm text-n-slate-9">
            {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.DAY_OFF') }}
          </span>
        </div>

        <div v-else class="flex-1 flex flex-col gap-2">
          <div
            v-for="(range, index) in day.ranges"
            :key="index"
            class="flex items-center gap-2"
          >
            <Input
              v-model="range.start"
              type="time"
              size="sm"
              custom-input-class="!h-9"
            />
            <span class="text-n-slate-9 text-sm">–</span>
            <Input
              v-model="range.end"
              type="time"
              size="sm"
              custom-input-class="!h-9"
              :message="
                isRangeInvalid(range)
                  ? t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.INVALID_RANGE')
                  : ''
              "
              :message-type="isRangeInvalid(range) ? 'error' : 'info'"
            />
            <button
              type="button"
              class="text-n-slate-9 hover:text-n-ruby-11 p-1.5 rounded-md hover:bg-n-alpha-2"
              :title="t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.REMOVE_RANGE')"
              :disabled="day.ranges.length === 1"
              :class="{
                'opacity-30 cursor-not-allowed': day.ranges.length === 1,
              }"
              @click="removeRange(day, index)"
            >
              <Icon icon="i-lucide-trash-2" class="size-4" />
            </button>
          </div>

          <div class="flex items-center gap-2 mt-0.5">
            <Button
              slate
              ghost
              xs
              icon="i-lucide-plus"
              :label="t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.ADD_RANGE')"
              @click="addRange(day)"
            />
            <AgendaDayCopyPopover
              :days="otherDaysFor(day.dayOfWeek)"
              @apply="targets => applyCopy(day, targets)"
            />
          </div>
        </div>
      </div>
    </div>

    <div
      v-if="!isLoading"
      class="flex items-center justify-end gap-2 mt-4 pt-3 border-t border-n-weak"
    >
      <span v-if="isDirty" class="text-xs text-n-amber-11 mr-auto">
        {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.UNSAVED_CHANGES') }}
      </span>
      <Button
        v-if="isDirty"
        slate
        outline
        sm
        :disabled="isSaving"
        :label="t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.DISCARD')"
        @click="discard"
      />
      <Button
        sm
        :is-loading="isSaving"
        :disabled="!isDirty || hasInvalidRange"
        :label="
          isSaving
            ? t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.SAVING')
            : t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.SAVE')
        "
        @click="save"
      />
    </div>
  </div>
</template>
