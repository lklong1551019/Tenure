import { defineConfig, type Plugin } from 'vitest/config'
import react from '@vitejs/plugin-react'

// The published page talks to its own origin, Google's sign-in, and the Drive API; nothing
// else. Added at build time only: the dev server injects inline scripts this would block.
const contentSecurityPolicy = [
  "default-src 'self'",
  "script-src 'self' https://accounts.google.com/gsi/client",
  // Google's sign-in script sets inline styles on what it adds; scripts stay locked down.
  "style-src 'self' 'unsafe-inline' https://accounts.google.com/gsi/style",
  "connect-src 'self' https://www.googleapis.com https://accounts.google.com/gsi/",
  'frame-src https://accounts.google.com/gsi/',
  "img-src 'self' data:",
  "base-uri 'none'",
  "form-action 'none'",
  "object-src 'none'",
].join('; ')

const securityHeaders: Plugin = {
  name: 'tenure-security-headers',
  apply: 'build',
  transformIndexHtml: () => [
    {
      tag: 'meta',
      attrs: { 'http-equiv': 'Content-Security-Policy', content: contentSecurityPolicy },
      injectTo: 'head-prepend',
    },
  ],
}

// `base` is where GitHub Pages serves the bundle: the repository's Pages site plus `app/`,
// which the Pages workflow fills from web/dist. The router is a HashRouter, so no other path
// has to agree with it. A mismatch shows as a blank page asking for /assets/... in vain.
export default defineConfig({
  plugins: [react(), securityHeaders],
  base: '/Tenure/app/',
  build: {
    outDir: 'dist',
    // Everything small inlined, so the page fetches nothing but its own bundle, Google's
    // sign-in script, and the Drive API.
    assetsInlineLimit: 4096,
    sourcemap: false,
  },
  server: {
    // Must match the Authorized JavaScript origin of the web OAuth client (docs/WEB.md).
    port: 5173,
    strictPort: true,
  },
  test: {
    // Domain and data tests run in Node; UI tests opt into jsdom per file.
    environment: 'node',
    include: ['src/**/*.test.{ts,tsx}', 'test/**/*.test.ts'],
  },
})
