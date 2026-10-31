/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** The web OAuth client id; `temp` or missing turns sync off (docs/WEB.md). */
  readonly VITE_GOOGLE_CLIENT_ID?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
