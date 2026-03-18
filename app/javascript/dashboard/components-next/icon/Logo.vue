<script setup>
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');
</script>

<template>
  <img
    v-if="globalConfig.logoThumbnail"
    v-bind="attrs"
    :src="globalConfig.logoThumbnail"
  />
  <svg
    v-else
    v-once
    v-bind="attrs"
    width="16"
    height="16"
    viewBox="0 0 16 16"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <rect width="16" height="16" rx="3" fill="#020817" />
    <defs>
      <linearGradient id="fdt-g" x1="3.5" y1="3" x2="11" y2="13" gradientUnits="userSpaceOnUse">
        <stop stop-color="#0ea5e9" />
        <stop offset="1" stop-color="#22d3ee" />
      </linearGradient>
    </defs>
    <!-- F vertical bar -->
    <rect x="3.5" y="3" width="1.5" height="10" fill="url(#fdt-g)" />
    <!-- F top bar -->
    <rect x="3.5" y="3" width="7" height="1.5" fill="url(#fdt-g)" />
    <!-- F middle bar -->
    <rect x="3.5" y="7" width="5" height="1.5" fill="url(#fdt-g)" />
    <!-- corner accent dots -->
    <rect x="12" y="2.5" width="1.5" height="1.5" fill="#22d3ee" opacity="0.6" />
    <rect x="12" y="12" width="1.5" height="1.5" fill="#22d3ee" opacity="0.4" />
  </svg>
</template>
