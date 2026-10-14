<!--
  The landing page's reveal diagnostic, for `/?debugReveal=1` on the dev server.

  It lives in its own file on purpose. The landing view loads it through a
  dynamic import that sits behind `import.meta.env.DEV`, so a production build
  never emits this chunk at all: neither the markup, nor the wording in it, nor
  the rules at the bottom of this file reach a deployed bundle. An inline
  `v-if="import.meta.env.DEV"` would not have achieved that - the template would
  still be compiled into the bundle, present but permanently false.

  It only reads: every value it shows is handed to it by the view, which reads
  the same numbers the reveal itself uses. Nothing here can change the page.
-->
<script setup lang="ts">
interface DebugSection {
  id: string
  top: number | null
  topFraction: number | null
  bottomFraction: number | null
  enter: number | null
  exit: number | null
  opacity: string | null
}

defineProps<{
  state: {
    section: string
    reducedMotion: boolean
    scrollTarget: string
    scrollY: number
    scrollMax: number
    armed: boolean
    sections: DebugSection[]
  }
}>()
</script>

<template>
  <aside class="landing-debug" aria-label="Reveal diagnostic (development only)">
    <p class="landing-debug__title">Reveal diagnostic — dev only</p>
    <dl class="landing-debug__rows">
      <div>
        <dt>Section in view</dt>
        <dd>{{ state.section }}</dd>
      </div>
      <div>
        <dt>prefers-reduced-motion: reduce</dt>
        <dd>{{ state.reducedMotion }}</dd>
      </div>
      <div>
        <dt>Scrolling element</dt>
        <dd>{{ state.scrollTarget }}</dd>
      </div>
      <div>
        <dt>Scroll offset</dt>
        <dd>{{ state.scrollY }}px of {{ state.scrollMax }}px</dd>
      </div>
      <div>
        <dt>Reveal armed</dt>
        <dd>{{ state.armed }}</dd>
      </div>
    </dl>
    <table class="landing-debug__table">
      <thead>
        <tr>
          <th scope="col">Section</th>
          <th scope="col">Wrapper top</th>
          <th scope="col">top / vh</th>
          <th scope="col">bottom / vh</th>
          <th scope="col">Entry</th>
          <th scope="col">Exit</th>
          <th scope="col">Opacity</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in state.sections" :key="row.id">
          <th scope="row">{{ row.id }}</th>
          <td>{{ row.top === null ? '—' : `${row.top}px` }}</td>
          <td>{{ row.topFraction ?? '—' }}</td>
          <td>{{ row.bottomFraction ?? '—' }}</td>
          <td>{{ row.enter ?? '—' }}</td>
          <td>{{ row.exit ?? '—' }}</td>
          <td>{{ row.opacity ?? '—' }}</td>
        </tr>
      </tbody>
    </table>
    <p class="landing-debug__hint">
      Opacity is the lower of Entry (arriving from below, read from the top edge) and Exit
      (leaving above, read from the bottom edge). Focus inside a group holds it at 1.
    </p>
  </aside>
</template>

<style>
/* Fixed to the corner so it never disturbs the page it is reading, and set apart
   from the page's own palette so it can never be mistaken for content. */
.landing-debug {
  position: fixed;
  top: 0.75rem;
  left: 0.75rem;
  z-index: 100;
  width: min(24rem, calc(100vw - 1.5rem));
  max-height: calc(100vh - 1.5rem);
  overflow: auto;
  padding: 0.7rem 0.8rem;
  border: 1px solid #1f6feb;
  border-radius: 0.5rem;
  background: rgba(8, 12, 24, 0.94);
  color: #e6edf3;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.7rem;
  line-height: 1.45;
}

.landing-debug__title {
  margin: 0 0 0.5rem;
  color: #79c0ff;
  font-weight: 700;
}

.landing-debug__rows {
  margin: 0 0 0.5rem;
}

.landing-debug__rows > div {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
}

.landing-debug__rows dt {
  color: #9fb3bd;
}

.landing-debug__rows dd {
  margin: 0;
  text-align: right;
}

.landing-debug__table {
  width: 100%;
  border-collapse: collapse;
}

.landing-debug__table th,
.landing-debug__table td {
  padding: 0.15rem 0.3rem;
  border-bottom: 1px solid rgba(230, 237, 243, 0.16);
  text-align: left;
  white-space: nowrap;
}

.landing-debug__table thead th {
  color: #9fb3bd;
  font-weight: 400;
}

.landing-debug__hint {
  margin: 0.5rem 0 0;
  color: #9fb3bd;
}

@media print {
  /* A development overlay has no business on paper either. */
  .landing-debug {
    display: none;
  }
}
</style>
