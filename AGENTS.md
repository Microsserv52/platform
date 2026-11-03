# Repository Guidelines & AI Context

This configuration file provides persistent instructions, workflows, safety guardrails, and coding conventions for AI agents (including Claude Code) working in this repository.

---

## 1. Information Retrieval Hierarchy & Repository Onboarding

Always resolve questions and locate project context using this multi-step lookup workflow before taking action:

1. **README & Root Instructions:** **Always read the README, `CLAUDE.md`, `AGENTS.md`, and any other local repository instructions first** to fully understand and adhere to the repository's rules and conventions.
2. **Targeted Docs Search:** If information is missing in root files, search in the `docs/` directory where the requested topic lives (e.g., `docs/architecture/`, `docs/api/`, `docs/database/`).
3. **Deep Docs Search:** If not immediately visible, perform a broader/deeper search across the entire `docs/` hierarchy.
4. **Clarifying Questions:** If documentation still lacks required context, ask the user a brief clarifying question before proceeding.

---

## 2. Information & Context Management

<PLEASE INSERT CONTEXT HERE (High-level project summary and tech stack details). Prompt to auto-detect: Scan the repository for configuration files (e.g. package.json, pyproject.toml, Cargo.toml, Go.mod, Dockerfile, README.md) and generate a concise 2-3 sentence overview of the project's primary function, framework, and main dependencies. Replace this block with the generated text.>

---

## 3. Directory Structure & File Organization

<PLEASE INSERT CONTEXT HERE (Directory map). Prompt to auto-detect: Run `tree -L 2 -I 'node_modules|.git|venv|__pycache__|.next|dist|build'` or examine the repository structure and list key directories with brief descriptions of what lives in each. Replace this block with the generated text.>

- **Directory Soundness:** Ensure the directory structure is sound according to the project documentation.
- **No File Stragglers:** Never leave temporary files, unorganized code snippets, or misplaced assets across the repository.
- **No Legacy Artifacts:**
  - Do NOT create or keep files like `_old`, `.bak`, `_v1`, or similar versioning suffix files. If a new version is needed, overwrite or delete the old file. Version control handles history.
  - Do NOT leave commented-out code blocks in version control unless there is a strong justification (e.g., explicit example usage or temporary debugging code with a clear comment). Otherwise, delete dead code.

---

## 4. Common Commands, Tooling & Official Setup

Always run: **linters, tests, formatters, pre-commit hooks**.

- **Official Tool Setup & Bootstrapping:** Whenever setting up, configuring, or initializing a new tool, framework, library, or dependency:
  - Search for and consult its official documentation.
  - **Always use official setup/getting-started commands, CLI generators, or initialization scripts** (e.g., `npm init`, `cargo new`, `npx create-...`, tool-specific `/init` or CLI commands).
  - Avoid manually creating configuration, layout, or boilerplate files from scratch when an official command or generator exists.

<PLEASE INSERT CONTEXT HERE (Common development terminal commands). Prompt to auto-detect: Inspect package.json scripts, Makefile, Taskfile, tox.ini, Makefile, or Makefile.py to identify common commands for testing, linting, formatting, building, and running dev servers. Provide a code block with shell commands. Replace this block with the generated text.>

---

## 5. Environment Awareness & Execution Context

Before performing commands, builds, or git operations, verify and adapt to the current execution environment:

- **Environment Detection:** Check environment variables, hostname, system user, or shell context to determine where execution is happening (e.g., local workstation vs. remote VPS, staging server, or CI/CD runner).
- **Local Development Workstation:** Continue with standard development workflows as normal (run local tests, feature development, auto-formatting, git pulls, etc.).
- **Remote Host / VPS / Staging / Production:**
  - **Take Extra Care:** Exercise extreme caution before executing commands that alter running processes, services, or network states.
  - **No Automatic Pulls:** Do **NOT** automatically `git pull` or checkout `latest` without explicit request or confirmation, as this may break live environments or overwrite manual server configurations.
  - **Minimal Footprint:** Avoid running heavy builds, destructive commands, or unverified scripts directly on live servers.

---

## 6. Timestamps & Timezone Policy

- **GH / System Timestamps:** GitHub returns UTC. All system timestamps must be handled in **UTC** internally.
- **Timezone Awareness:** All system `timestamps` MUST contain explicit `timezone` information.
- **Usage & Conversion:** For display, AI chat, or user interaction, check the configured local timezone and convert UTC timestamps to the user's local timezone.
- **No Hardcoded Timezones:** NEVER hardcode timezones inside code logic or queries. Store configured timezones at least in a top-level script variable or environment variable using standardized naming (refer to `docs/` for specific environment variable conventions).

---

## 7. Architectural Boundaries & Repository Separation of Concerns

- **Scope Limit:** Do not modify responsibilities outside the scope of this repository.
- **Cross-Repo Changes:** If a change requires modifying responsibilities outside this codebase (e.g., a database schema change that belongs in a separate database migration repository), consult `docs/`, create a Pull Request in the appropriate target repository, and limit changes in this repository to related integration points. This prevents agents from mixing repository concerns.
- **Adding New Resources/Dependencies:** When creating a new directory or adding a dependency (code, API, library, external resource, pattern, application, script, etc.), evaluate:
  1. _Does it need to exist?_
  2. _Does it adhere to the overall project structure?_
  3. _Does the codebase already have a way to implement it_ (via `lib/`, a native language feature, or a shared dependency)?
  4. _If yes:_ You may add it, but it **MUST be documented**.
- **Creating Files:** Apply reasonable discretion when creating standard source/test files within existing patterns, adhering to the structure above.

---

## 8. Security & Production Guardrails

- **Production Authorization:** Any changes in production—whether commits, database writes, uploads, deploys, or remote service modifications—**MUST have explicit authorization from the user**.
- **Action Prompts:** If an action requiring authorization is needed, place the request along with an explicit description of what it will do at the **bottom of your reply**.
- **Minimal Production Impact:** Try to keep changes and touching production environments to a absolute minimum.
- **Drastic Measures Warning:** Never take drastic measures (e.g., force pushes, deleting production tables, dropping indexes, nuking storage buckets) without a prominent, clear, and detailed warning explaining the consequences.
- **Official Channels:** Always follow correct, established deployment pipelines, CI/CD procedures, and permission channels.
- **Secrets in Version Control:** **NEVER** add secrets, tokens, API keys, credentials, or private certificates to version control.
  - Use `.gitignore`, environment variables, vaults, or secret managers.
  - Plain encoding (e.g., Base64) is **NOT** sufficient security.
  - Ensure secrets are not accessible externally after deployment or logging.

---

## 9. Quality Control & Safety Rules

- **Pre-commit Checks:** Always execute linters, tests, formatters, and pre-commit hooks before finalizing changes.
- **Verification:** Ensure that code compiles/runs and all relevant test suites pass before considering a task complete.

---

## 10. Code Style, Architectural Principles & Engineering Standards

- **Core Principles:** Adhere strictly to industry-grade software engineering practices:
  - **DRY (Don't Repeat Yourself):** Avoid redundant logic; extract common patterns into reusable helpers, functions, or modules.
  - **Microservices & Separation of Concerns:** Design bounded contexts, maintain clean module boundaries, and prevent cross-domain pollution.
  - **Clean Code & Enterprise Standards:** Follow robust enterprise patterns, proper design principles, and maximum maintainability.
  - **No Reinventing the Wheel / No Custom Complex Logic:** Never self-implement complex algorithms, custom state machines, validation engines, or utilities from scratch when an established framework tool, built-in utility, or trusted library exists.
  - **Framework-First Approach:** Always leverage native framework tools, built-ins, standard libraries, and established idioms.
  - **Delegate Always:** Offload routing, state management, validation, ORM mapping, and infrastructure concerns to framework tools and battle-tested libraries rather than writing custom procedural logic.
- **Minimal Comments:** Keep code comments to a minimum. The code itself should be descriptive and self-documenting through clear naming.
- **Comment Justifications:** Comments should only be used to justify non-obvious/strange patterns, explain complex business logic, or serve as API documentation. Always keep comments straightforward and concise.
- **Documentation Offloading:** Make sure everything is clear but not excessive in code. Keep code explainable, and offload larger context, architectural explanations, and domain concepts into `docs/`.
- **Markdown & README Standards:**
  - **Full GFM Syntax Usage:** When creating or updating READMEs and Markdown documentation, utilize all available resources from [GitHub Basic Writing and Formatting Syntax](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax) (tables, callout alerts, task lists, code blocks with syntax highlighting, collapsible sections, diagrams, foot notes) and [Zensical Documentation](https://zensical.org/docs/authoring/markdown) depending whether the content is for GitHub or Zensical.
  - **Comprehensive & Precise:** Make documentation comprehensive, clean, straight to the point, and non-repetitive. Provide as much detail and concrete instruction as possible.
  - **Zero Missing Docs:** Think twice before stating the obvious, but **NEVER leave anything required undocumented**.

---

## 11. Branch Protection & Git Conventions

- **STRICT NO DIRECT COMMITS TO PROTECTED BRANCHES:**
  - **NEVER commit directly** to `main`, `master`, `deploy`, `prod`, `production`, or any branch that is live or serves as a primary release branch.
  - **Feature Branch Creation:** Any new feature, fix, refactor, or task MUST be created in a dedicated new branch named after the feature/task (e.g., `feature/user-auth`, `fix/login-bug`).
  - **Merging Strategy:** Merge changes into integration branches like `development` or `staging` according to the repository's rules.
  - **Escalation:** If for any reason this branching workflow cannot be followed or a branch state is ambiguous, **stop immediately and ask the user clarifying questions**.
- **Sync Before Working & Before PRs:**
  - Always run `git pull` (or fetch/rebase as appropriate) to update your local branch before starting any task or writing code (on local dev environments).
  - Before creating a Pull Request or pushing final commits, pull/sync the latest target branch changes again, resolve any conflicts, and re-run all tests/linters to guarantee the PR is up to date and clean.
- **Branch Naming:** `<PLEASE INSERT CONTEXT HERE (e.g., feature/, fix/, chore/ followed by ticket/desc). Prompt to auto-detect: Run`git branch --show-current`or inspect recent branches to determine the naming convention.>`
- **Commit Messages:** `<PLEASE INSERT CONTEXT HERE (e.g., Conventional Commits format: feat:, fix:, chore:, refactor:). Prompt to auto-detect: Analyze recent git log messages (`git log -n 10 --oneline`) and summarize the commit style and prefix convention.>`
- **Diff & Pragmatic Review Checklist:** Before committing, merging, or creating a PR, always review the `git diff`:
  - Check for **stray files** or unorganized/temporary artifacts (refer to Section 3).
  - Check for **unnecessary files** or dead code (refer to Section 3).
  - Evaluate for **excessive or unrelated diffs**; judge loosely whether the requested work reasonably requires the changes made. If it looks reasonable and proportionate, proceed.

---

## 12. Test & Debugging Protocol

- **Failing Tests:** If a test fails after your changes, **never** delete, comment out, or weaken test assertions simply to make the build pass unless explicitly instructed.
- **Root Cause Analysis:** Thoroughly analyze test failures, identify regressions or missed edge cases, and fix the underlying implementation.
- **Regression Verification:** Run the full relevant test suite locally to ensure no surrounding functionality was broken.

---

## 13. Dependency & Version Pinning Management

- **Lockfiles:** When adding, updating, or removing dependencies, always update the project lockfile (`package-lock.json`, `poetry.lock`, `uv.lock`, `Cargo.lock`, `go.sum`, etc.).
- **Semantic Versioning Strategy:**
  - **Major Versions:** Always pin Major versions explicitly to avoid breaking changes (e.g., `^1.0.0` or `=1.x.x`).
  - **Minor Versions:** Evaluate on a case-by-case basis whether to pin Minor versions strictly or permit minor feature updates.
  - **Patch & Security Updates:** Allow automatic non-breaking patch (`~` / `1.2.x`) and security updates to ensure non-disruptive bug fixes and security hardening.
  - **Container & Base Images:** Never pin Docker/container images, base actions, or external references to `:latest` tags unless there is an explicit, documented reason. Fetch the current stable version number and pin to explicit tags or digests.
- **Necessity & Documentation:** Before adding new third-party libraries, verify if the codebase or language standard library already offers equivalent functionality (refer to Section 7). Document any newly added dependencies.

---

## 14. Upgrade & Migration Protocol

When performing major version upgrades, framework transitions, schema updates, or tool migrations:

- **Strict Doc Compliance:** Locate and thoroughly read the official migration guides and project documentation before taking any action.
- **Exact Step-by-Step Order:** Strictly follow the official migration instructions in the exact sequence outlined by the maintainers/docs.
- **Sequential Intermediate Steps:** Execute all necessary intermediate version upgrades (e.g., migrating `v1 -> v2 -> v3` rather than jumping directly `v1 -> v3`) to preserve backward compatibility, execute incremental migrations, and ensure zero data/logic loss.
- **Step Validation:** Verify each intermediate step by running tests and linters before proceeding to the next step in the migration sequence.

---

## 15. Feature Lifecycle & Impact Analysis

When **adding, removing, modifying, or refactoring** a feature, always perform a holistic impact analysis and update all related downstream requirements to keep the repository fresh and fully operational:

- **Documentation:** Update API specs, READMEs, architectural notes in `docs/`, and user guides to reflect changes.
- **Observability:** Add or update metrics, structured logging, distributed tracing, and health check endpoints affected by the change.
- **Deployment Requirements:** Adjust environment variables, configuration files, Dockerfiles, CI/CD pipelines, and infrastructure manifests as required.
- **Security & Access Controls:** Verify and update authentication scopes, authorization checks, API key roles, and CORS settings.
- **Database & Storage:** Include required database migrations, seed data updates, or bucket policy changes.
- **Test Coverage:** Add or update unit, integration, and end-to-end tests covering the changed functionality.
