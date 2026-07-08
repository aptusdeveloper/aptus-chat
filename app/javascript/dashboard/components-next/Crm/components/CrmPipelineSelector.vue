<script setup>
defineProps({
  pipelines: {
    type: Array,
    default: () => [],
  },
  modelValue: {
    type: String,
    default: null,
  },
});

const emit = defineEmits(['update:modelValue']);
</script>

<template>
  <select
    :value="modelValue"
    class="text-sm bg-white dark:bg-n-solid-2 border border-n-weak rounded-lg px-3 py-2 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 min-w-40"
    @change="emit('update:modelValue', $event.target.value)"
  >
    <option
      v-for="pipeline in pipelines"
      :key="pipeline.id"
      :value="pipeline.id"
    >
      {{ pipeline.name }}
    </option>
  </select>
</template>
