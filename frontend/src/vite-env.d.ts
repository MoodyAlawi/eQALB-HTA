/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Base URL of the model API. Defaults to /api (proxied to the FastAPI service). */
  readonly VITE_API_BASE?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
