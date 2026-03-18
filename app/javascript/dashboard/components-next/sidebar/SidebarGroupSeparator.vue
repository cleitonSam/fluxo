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
    <Icon v-if="icon" :icon="icon" class="size-4 text-cyan-500/60 drop-shadow-[0_0_3px_rgba(34,211,238,0.4)]" />
    <span class="text-sm font-medium leading-5 flex-grow">
      {{ label }}
    </span>
  </div>
</template>
