import js from '@eslint/js'
import globals from 'globals'
import reactHooks from 'eslint-plugin-react-hooks'
import tseslint from 'typescript-eslint'

// The layers mirror the Swift package (docs/WEB.md): domain imports nothing of ours, data and
// ui import domain only, app sees all. Same rule as scripts/check-deps.sh, enforced here.
const layer = (patterns, message) => ({
  'no-restricted-imports': ['error', { patterns: [{ group: patterns, message }] }],
})

export default tseslint.config(
  { ignores: ['dist', 'node_modules'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: { globals: { ...globals.browser } },
    plugins: { 'react-hooks': reactHooks },
    rules: {
      ...reactHooks.configs.recommended.rules,
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', ignoreRestSiblings: true },
      ],
    },
  },
  // Tests may reach across layers, as Packages/IntegrationTests does.
  {
    files: ['src/domain/**'],
    ignores: ['**/*.test.ts'],
    rules: layer(
      ['**/data/**', '**/ui/**', '**/app/**', 'react', 'react-*'],
      'domain is pure: it imports nothing but other domain files.',
    ),
  },
  {
    files: ['src/data/**'],
    ignores: ['**/*.test.ts'],
    rules: layer(['**/ui/**', '**/app/**', 'react', 'react-*'], 'data depends on domain only.'),
  },
  {
    files: ['src/ui/**'],
    ignores: ['**/*.test.{ts,tsx}'],
    rules: layer(['**/data/**', '**/app/**'], 'ui depends on domain only; app wires data in.'),
  },
)
