<script setup>
import { useAttrs } from 'vue';

const attrs = useAttrs();
const lightIcon = '/brand-assets/robo-azul.svg';
const darkIcon = '/brand-assets/robo-branco.svg';
</script>

<template>
  <img v-bind="attrs" :src="lightIcon" class="dark:hidden" />
  <img v-bind="attrs" :src="darkIcon" class="hidden dark:block" />
</template>
