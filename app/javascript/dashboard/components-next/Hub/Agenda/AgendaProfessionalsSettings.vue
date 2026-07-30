<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AgendaTabs from './AgendaTabs.vue';
import AgendaWeeklyAvailabilityEditor from './AgendaWeeklyAvailabilityEditor.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const store = useStore();
const { t } = useI18n();

const professionals = computed(() => store.getters['agenda/professionals']);
const uiFlags = computed(() => store.getters['agenda/uiFlags']);

const expandedProfessionalId = ref(null);
function toggleAvailability(professional) {
  expandedProfessionalId.value =
    expandedProfessionalId.value === professional.id ? null : professional.id;
}

// ----- Create / edit professional -----
const formDialogRef = ref(null);
const editingId = ref(null);
const isSaving = ref(false);

const emptyForm = () => ({
  name: '',
  specialty: '',
  timezone: 'America/Sao_Paulo',
  color: '#3B82F6',
  active: true,
});
const form = reactive(emptyForm());

function openCreateForm() {
  editingId.value = null;
  Object.assign(form, emptyForm());
  formDialogRef.value?.open();
}

function openEditForm(professional) {
  editingId.value = professional.id;
  Object.assign(form, {
    name: professional.name,
    specialty: professional.specialty || '',
    timezone: professional.timezone,
    color: professional.color || '#3B82F6',
    active: professional.active,
  });
  formDialogRef.value?.open();
}

async function saveProfessional() {
  isSaving.value = true;
  try {
    if (editingId.value) {
      await store.dispatch('agenda/updateProfessional', {
        id: editingId.value,
        ...form,
      });
    } else {
      await store.dispatch('agenda/createProfessional', { ...form });
    }
    formDialogRef.value?.close();
  } catch (error) {
    useAlert(t('HUB.AGENDA.PROFESSIONALS.FORM.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
}

// ----- Delete professional -----
const deleteDialogRef = ref(null);
const deletingProfessional = ref(null);
const isDeleting = ref(false);

function openDeleteDialog(professional) {
  deletingProfessional.value = professional;
  deleteDialogRef.value?.open();
}

async function confirmDelete() {
  if (!deletingProfessional.value) return;
  isDeleting.value = true;
  try {
    await store.dispatch(
      'agenda/deleteProfessional',
      deletingProfessional.value.id
    );
    deleteDialogRef.value?.close();
  } catch (error) {
    useAlert(t('HUB.AGENDA.PROFESSIONALS.DELETE_ERROR'));
  } finally {
    isDeleting.value = false;
  }
}

// ----- Date-specific overrides (exceptions to the weekly schedule) -----
const emptyOverride = () => ({
  date: '',
  unavailable: true,
  start: '09:00',
  end: '18:00',
});
const overrideForm = reactive(emptyOverride());

function availabilitiesFor(professionalId) {
  return store.getters['agenda/availabilitiesForProfessional'](professionalId);
}

function overridesFor(professionalId) {
  return availabilitiesFor(professionalId)
    .filter(a => a.date)
    .sort((a, b) => a.date.localeCompare(b.date));
}

async function addOverride(professionalId) {
  const [startHour, startMinutes] = overrideForm.start.split(':').map(Number);
  const [endHour, endMinutes] = overrideForm.end.split(':').map(Number);
  await store.dispatch('agenda/createAvailability', {
    professionalId,
    availabilityData: {
      date: overrideForm.date,
      unavailable: overrideForm.unavailable,
      start_hour: overrideForm.unavailable ? null : startHour,
      start_minutes: overrideForm.unavailable ? null : startMinutes,
      end_hour: overrideForm.unavailable ? null : endHour,
      end_minutes: overrideForm.unavailable ? null : endMinutes,
    },
  });
  Object.assign(overrideForm, emptyOverride());
}

async function deleteOverride(professionalId, availability) {
  await store.dispatch('agenda/deleteAvailability', {
    professionalId,
    id: availability.id,
  });
}

function pad(value) {
  return String(value).padStart(2, '0');
}

onMounted(() => {
  store.dispatch('agenda/fetchProfessionals');
});
</script>

<template>
  <div class="flex-1 overflow-y-auto p-4">
    <div class="mb-4 flex items-center justify-between">
      <div>
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('HUB.AGENDA.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-10">{{ t('HUB.AGENDA.SUBTITLE') }}</p>
      </div>
      <Button
        icon="i-lucide-plus"
        :label="t('HUB.AGENDA.PROFESSIONALS.NEW')"
        @click="openCreateForm"
      />
    </div>

    <AgendaTabs />

    <div v-if="uiFlags.isFetchingProfessionals" class="text-sm text-n-slate-10">
      {{ t('HUB.AGENDA.PROFESSIONALS.LOADING') }}
    </div>
    <div v-else-if="!professionals.length" class="text-sm text-n-slate-10">
      {{ t('HUB.AGENDA.PROFESSIONALS.EMPTY') }}
    </div>

    <div v-else class="flex flex-col gap-3">
      <div
        v-for="professional in professionals"
        :key="professional.id"
        class="rounded-lg border border-n-weak bg-n-solid-1 dark:bg-n-solid-2 overflow-hidden"
      >
        <div class="flex flex-wrap items-center gap-3 p-4">
          <span
            class="size-3 rounded-full shrink-0"
            :style="{ backgroundColor: professional.color || '#94A3B8' }"
          />
          <div class="min-w-0 mr-auto">
            <p class="text-sm font-semibold text-n-slate-12 truncate">
              {{ professional.name }}
            </p>
            <p class="text-xs text-n-slate-9 truncate">
              {{ professional.specialty }} · {{ professional.timezone }}
            </p>
          </div>
          <span
            class="inline-flex items-center h-6 px-2 rounded-md text-xs font-medium"
            :class="
              professional.active
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-slate-3 text-n-slate-11'
            "
          >
            {{
              professional.active
                ? t('HUB.AGENDA.PROFESSIONALS.FORM.ACTIVE')
                : t('HUB.AGENDA.PROFESSIONALS.FORM.INACTIVE')
            }}
          </span>
          <Button
            slate
            outline
            sm
            :icon="
              expandedProfessionalId === professional.id
                ? 'i-lucide-chevron-up'
                : 'i-lucide-calendar-clock'
            "
            :label="t('HUB.AGENDA.PROFESSIONALS.MANAGE_AVAILABILITY')"
            @click="toggleAvailability(professional)"
          />
          <Button
            slate
            outline
            sm
            icon="i-lucide-pencil"
            :title="t('HUB.AGENDA.PROFESSIONALS.FORM.SAVE')"
            @click="openEditForm(professional)"
          />
          <Button
            ruby
            outline
            sm
            icon="i-lucide-trash-2"
            :title="t('HUB.AGENDA.PROFESSIONALS.FORM.DELETE')"
            @click="openDeleteDialog(professional)"
          />
        </div>

        <div
          v-if="expandedProfessionalId === professional.id"
          class="border-t border-n-weak bg-n-alpha-1 p-4"
        >
          <h4 class="text-sm font-semibold text-n-slate-12 mb-3">
            {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.TITLE') }}
          </h4>
          <AgendaWeeklyAvailabilityEditor :professional-id="professional.id" />

          <div class="mt-6 pt-4 border-t border-n-weak">
            <h4 class="text-sm font-semibold text-n-slate-12 mb-1">
              {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.OVERRIDES_TITLE') }}
            </h4>
            <p class="text-xs text-n-slate-9 mb-3">
              {{
                t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.OVERRIDES_SUBTITLE')
              }}
            </p>

            <ul
              v-if="overridesFor(professional.id).length"
              class="flex flex-col gap-1 mb-3"
            >
              <li
                v-for="availability in overridesFor(professional.id)"
                :key="availability.id"
                class="flex items-center justify-between text-sm text-n-slate-12 bg-n-alpha-1 rounded-md px-3 py-1.5"
              >
                <span>
                  {{ availability.date }}
                  <template v-if="availability.unavailable">
                    —
                    {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.UNAVAILABLE') }}
                  </template>
                  <template v-else>
                    · {{ pad(availability.start_hour) }}:{{
                      pad(availability.start_minutes)
                    }}
                    – {{ pad(availability.end_hour) }}:{{
                      pad(availability.end_minutes)
                    }}
                  </template>
                </span>
                <button
                  type="button"
                  class="text-n-slate-9 hover:text-n-ruby-11 p-1 rounded hover:bg-n-alpha-2"
                  @click="deleteOverride(professional.id, availability)"
                >
                  <Icon icon="i-lucide-trash-2" class="size-3.5" />
                </button>
              </li>
            </ul>

            <div class="flex flex-wrap items-end gap-2">
              <Input
                v-model="overrideForm.date"
                type="date"
                size="sm"
                :label="
                  t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.DATE_OVERRIDE')
                "
                custom-input-class="!h-9"
              />
              <label
                class="inline-flex items-center gap-2 text-xs text-n-slate-12 pb-2"
              >
                <Checkbox v-model="overrideForm.unavailable" />
                {{ t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.UNAVAILABLE') }}
              </label>
              <template v-if="!overrideForm.unavailable">
                <Input
                  v-model="overrideForm.start"
                  type="time"
                  size="sm"
                  :label="t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.START')"
                  custom-input-class="!h-9"
                />
                <Input
                  v-model="overrideForm.end"
                  type="time"
                  size="sm"
                  :label="t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.END')"
                  custom-input-class="!h-9"
                />
              </template>
              <Button
                sm
                icon="i-lucide-plus"
                :disabled="!overrideForm.date"
                :label="
                  t('HUB.AGENDA.PROFESSIONALS.AVAILABILITY.ADD_DATE_OVERRIDE')
                "
                @click="addOverride(professional.id)"
              />
            </div>
          </div>
        </div>
      </div>
    </div>

    <Dialog
      ref="formDialogRef"
      :title="
        editingId
          ? t('HUB.AGENDA.PROFESSIONALS.EDIT')
          : t('HUB.AGENDA.PROFESSIONALS.NEW')
      "
      :is-loading="isSaving"
      :disable-confirm-button="!form.name"
      :confirm-button-label="t('HUB.AGENDA.PROFESSIONALS.FORM.SAVE')"
      @confirm="saveProfessional"
    >
      <div class="flex flex-col gap-4">
        <Input
          v-model="form.name"
          :label="t('HUB.AGENDA.PROFESSIONALS.FORM.NAME')"
          :placeholder="t('HUB.AGENDA.PROFESSIONALS.FORM.NAME_PLACEHOLDER')"
        />
        <Input
          v-model="form.specialty"
          :label="t('HUB.AGENDA.PROFESSIONALS.FORM.SPECIALTY')"
          :placeholder="
            t('HUB.AGENDA.PROFESSIONALS.FORM.SPECIALTY_PLACEHOLDER')
          "
        />
        <Input
          v-model="form.timezone"
          :label="t('HUB.AGENDA.PROFESSIONALS.FORM.TIMEZONE')"
        />
        <div>
          <label class="block mb-1 text-xs font-medium text-n-slate-11">
            {{ t('HUB.AGENDA.PROFESSIONALS.FORM.COLOR') }}
          </label>
          <input
            v-model="form.color"
            type="color"
            class="h-9 w-16 rounded border border-n-weak bg-transparent cursor-pointer"
          />
        </div>
        <label class="inline-flex items-center gap-2 text-sm text-n-slate-12">
          <Switch v-model="form.active" />
          {{ t('HUB.AGENDA.PROFESSIONALS.FORM.ACTIVE') }}
        </label>
      </div>
    </Dialog>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('HUB.AGENDA.PROFESSIONALS.DELETE_CONFIRM_TITLE')"
      :description="t('HUB.AGENDA.PROFESSIONALS.DELETE_CONFIRM')"
      :is-loading="isDeleting"
      :confirm-button-label="t('HUB.AGENDA.PROFESSIONALS.FORM.DELETE')"
      @confirm="confirmDelete"
    />
  </div>
</template>
