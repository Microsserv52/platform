---
icon: lucide/package
---

# Dependencies and official initialization

The owner approved npm, MUI/Emotion integration/icons, TanStack Query/Table,
React Hook Form with Zod/resolvers, Faro SDK/tracing, Prettier, Vitest and
Playwright, in addition to the requested Next.js/React/TypeScript/Tailwind stack.
No additional runtime library has been introduced beyond that approval.

The official `create-next-app@16.4.5` initialized each application with
TypeScript, ESLint, Tailwind, App Router, src directory and npm. Official
`create-playwright@1.17.139` initialized browser tooling. Pre-commit was already
installed on the workstation; its official sample/configuration guidance was
used for local hooks that call existing npm checks and install no hook packages.

Node.js 24 is declared in `.nvmrc` and engines. The generator originally supplied
Node 20 types, which conflicted with current Vitest; matching Node 24 types
resolved the conflict without force/legacy-peer-deps. Each repository commits
its own npm-generated lockfile. Runtime additions use patch ranges and lockfiles;
framework versions supplied by the generator are explicit.

## Responsibilities

- MUI owns controls/dialogs and Emotion's App Router cache; Tailwind owns utility
  styling. CSS layers place MUI before utilities. System/Georgia fonts avoid a
  font network dependency.
- Zod validates API responses, stored cart data and forms; TypeScript checks code.
  React Hook Form owns form state; TanStack Query owns server state.
- TanStack Table v9 supplies sorting/pagination with explicit selected features.
  Virtualization, Pacer and use-debounce are not installed without a measured need.
- Native fetch, AbortController, URL, React state and Intl cover transport,
  cancellation, cart/UI state, currency and timezone-aware display. No time library.
- Faro SDK/tracing is configurable; Umami uses its official script via next/script.
- Playwright tests exercise labeled fixtures; Vitest checks contracts/API behavior.
- iron-session was removed from the proposal: static hosting uses Gateway sessions.

## Resolved direct packages

| Package                       | Locked version | Repositories          |
| ----------------------------- | -------------- | --------------------- |
| `@emotion/cache`              | `11.14.0`      | landing, store, admin |
| `@emotion/react`              | `11.14.0`      | landing, store, admin |
| `@emotion/styled`             | `11.14.1`      | landing, store, admin |
| `@grafana/faro-web-sdk`       | `2.13.0`       | landing, store, admin |
| `@grafana/faro-web-tracing`   | `2.13.0`       | landing, store, admin |
| `@hookform/resolvers`         | `7.0.5`        | store, admin          |
| `@mui/icons-material`         | `9.5.0`        | landing, store, admin |
| `@mui/material`               | `9.5.0`        | landing, store, admin |
| `@mui/material-nextjs`        | `9.5.0`        | landing, store, admin |
| `@playwright/test`            | `1.65.0`       | landing, store, admin |
| `@tailwindcss/turbopack`      | `4.3.5`        | landing, store, admin |
| `@tanstack/react-query`       | `5.107.1`      | landing, store, admin |
| `@tanstack/react-table`       | `9.3.1`        | admin                 |
| `@types/node`                 | `24.19.2`      | landing, store, admin |
| `@types/react`                | `19.3.0`       | landing, store, admin |
| `@types/react-dom`            | `19.3.0`       | landing, store, admin |
| `babel-plugin-react-compiler` | `1.0.0`        | landing, store, admin |
| `eslint`                      | `9.39.5`       | landing, store, admin |
| `eslint-config-next`          | `16.4.5`       | landing, store, admin |
| `next`                        | `16.4.5`       | landing, store, admin |
| `prettier`                    | `3.9.10`       | landing, store, admin |
| `react`                       | `19.3.0`       | landing, store, admin |
| `react-dom`                   | `19.3.0`       | landing, store, admin |
| `react-hook-form`             | `7.91.0`       | store, admin          |
| `tailwindcss`                 | `4.3.5`        | landing, store, admin |
| `typescript`                  | `5.9.3`        | landing, store, admin |
| `vitest`                      | `5.1.0`        | landing, store, admin |
| `zod`                         | `4.6.7`        | landing, store, admin |

## Audit and conditional additions

The initial audit reported eight moderate **development-tooling** findings
through eslint-config-next/typescript-eslint's minimatch dependency, associated
with [GHSA-g3hv-75wg-m249](https://github.com/advisories/GHSA-g3hv-75wg-m249).
The advisory's fix moves to minimatch 11; npm proposes a framework-config major
change. No automatic force upgrade is performed. This is recorded for a reviewed
tooling update; the runtime export contains no Node tooling. Do not claim a clean
full dependency audit until this is resolved.

21st.dev was used for visual research, not source copying. A chosen third-party
component requires license/accessibility review and approval of its added
packages. Offline caching, source-map CLI/upload, charting, localization, time
arithmetic, a shared component package or commercial MUI X also need separate
approval and documentation.

## Official references

- [Next.js generator](https://nextjs.org/docs/app/api-reference/cli/create-next-app)
- [MUI/Next.js](https://mui.com/material-ui/integrations/nextjs/) and
  [MUI/Tailwind](https://mui.com/material-ui/integrations/tailwindcss/tailwindcss-v4/)
- [TanStack Query](https://tanstack.com/query/latest/docs/framework/react/overview)
  and [Table](https://tanstack.com/table/latest/docs/overview)
- [React Hook Form](https://react-hook-form.com/get-started),
  [resolvers](https://github.com/react-hook-form/resolvers), [Zod](https://zod.dev/)
- [Playwright](https://playwright.dev/docs/intro), [Vitest](https://vitest.dev/guide/),
  [Prettier](https://prettier.io/docs/install), [pre-commit local hooks](https://pre-commit.com/#repository-local-hooks)
