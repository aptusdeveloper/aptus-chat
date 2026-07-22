<script>
export default {
  props: {
    message: { type: String, default: '' },
    action: {
      type: Object,
      default: () => ({}),
    },
  },
  computed: {
    isActionPresent() {
      return this.action && this.action.message;
    },
  },
};
</script>

<template>
  <div
    class="bg-n-slate-12 dark:bg-n-slate-7 rounded-md drop-shadow-md mb-4 max-w-[48rem] inline-flex items-start min-w-[22rem] py-4 px-5"
    :class="isActionPresent ? 'justify-between' : 'justify-center'"
  >
    <div
      class="text-sm font-medium leading-6 text-left text-white whitespace-pre-line"
    >
      {{ message }}
    </div>
    <div v-if="isActionPresent" class="ml-4">
      <router-link v-if="action.type == 'link'" :to="action.to" class="">
        {{ action.message }}
      </router-link>
    </div>
  </div>
</template>
