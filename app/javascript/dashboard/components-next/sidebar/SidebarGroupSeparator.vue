<script setup>
import Icon from 'next/icon/Icon.vue';

defineProps({
  label: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div
    class="flex items-center gap-2 px-2 py-1.5 rounded-lg h-8 text-n-slate-10 select-none pointer-events-none"
  >
    <Icon v-if="icon" :icon="icon" class="size-4 text-[rgba(6,182,212,0.6)] drop-shadow-[0_0_3px_rgba(34,211,238,0.4)]" />
    <span class="text-sm font-mono font-medium leading-5 flex-grow tracking-wider uppercase text-[10px]">
      {{ label }}
    </span>
  </div>
</template>
