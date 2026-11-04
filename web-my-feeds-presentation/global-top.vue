<template>
  <div v-if="$nav.currentPage > 1 && $nav.currentPage < $nav.total" class="mark">
    <img src="/logo.png" alt="" />
    <span>My Feeds · {{ $nav.currentPage }} / {{ $nav.total }}</span>
  </div>
</template>
