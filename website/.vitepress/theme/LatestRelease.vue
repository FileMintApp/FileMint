<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { getLatestRelease, LATEST_RELEASE_URL } from './release.mjs'

const props = defineProps({ lang: { type: String, default: 'zh' } })
const release = ref(null)
const label = computed(() => props.lang === 'en' ? 'Latest stable release' : '最新正式版')
let active = true

onMounted(async () => {
  const latest = await getLatestRelease()
  if (active) release.value = latest
})
onUnmounted(() => { active = false })
</script>

<template>
  <a
    class="latest-release"
    :href="release?.url ?? LATEST_RELEASE_URL"
    target="_blank"
    rel="noopener noreferrer"
    aria-live="polite"
    aria-atomic="true"
  >
    <span>{{ label }}</span>
    <span v-if="release" class="latest-release-version">v{{ release.version }}</span>
    <span aria-hidden="true">↗</span>
  </a>
</template>

<style scoped>
.latest-release {
  display: inline-flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.45em;
}
.latest-release-version {
  font-variant-numeric: tabular-nums;
}
</style>
