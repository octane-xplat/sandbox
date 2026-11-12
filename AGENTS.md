# AGENTS.md

Octane Xplat app — one TypeScript codebase for web + iOS + Android (Octane

- NativeScript).

Before writing code, read `.agents/skills/xplat/SKILL.md` (or invoke the
`xplat` skill). Its invariants are enforced by `pnpm lint` — violations
usually still compile but silently break on one platform.

## One fresh worktree per experiment

`main` is the blank-slate starter. Keep it ready for the next experiment:
framework upgrades, shared tooling, and these instructions may change there,
but experiment screens, dependencies, and results belong on experiment branches.
Do not merge experiments into `main` unless the user explicitly asks.

Whenever you create commits in this sandbox, push the committed branch to
`origin` before handing the work back. This applies to experiment branches
and permitted changes on `main`. Use `git push -u origin HEAD` for the first
push and `git push origin HEAD` for subsequent pushes. Creating commits also
authorizes pushing that branch; do not leave completed commits only locally.
If a push fails, report the blocker and preserve the local commits. Do not
force-push to resolve a rejection.

When the user asks to try something new, start a new task in a new worktree
on a fresh branch based on the latest `origin/main`. This request authorizes
creating that experiment's task, branch, and worktree. Never base a new
experiment on the current experiment branch or reuse another experiment's
worktree. Continue an existing experiment in its own task and worktree when
the user is asking for a follow-up. An experiment task must not create another
task just to begin its assigned experiment.

1. Identify the canonical sandbox checkout (locally,
   `~/dev/octane-xplat/sandbox`) and inspect its status and worktrees. Fetch
   the baseline without switching branches or changing existing work:

   ```sh
   git -C /path/to/sandbox status --short --branch
   git -C /path/to/sandbox worktree list
   git -C /path/to/sandbox fetch origin main
   ```

   Use the fetched `origin/main` as the base. If it cannot be fetched, report
   the blocker instead of silently starting from an experiment or stale base.
   Preserve all existing branches, worktrees, and uncommitted changes.

2. Prefer Goddard when `goddard-agent` is available. Check its installed
   `create --help`, then request a **worktree** task with the base explicit:

   ```sh
   goddard-agent create --project /path/to/sandbox \
     --workspace worktree --base-branch origin/main \
     --text 'Experiment: REPLACE_WITH_GOAL. Work only in this assigned worktree and fresh branch. Read AGENTS.md. Implement and verify the experiment, commit the result, push the branch to origin, and report the branch, worktree path, and checks. Do not merge into main or create another task for this experiment.'
   ```

   Replace the path and goal before running. Let Goddard allocate the fresh
   branch and worktree; do not first create another branch or worktree for
   the same experiment. Give the new task the user's full requirements,
   relevant context, and any requested local framework checkout. Verify the
   allocated branch and worktree start from the fetched baseline. Hand the
   experiment to that task and link it in the reply. A task-creation receipt
   is not evidence that the experiment itself has finished.

3. If Goddard is unavailable, prefer an equivalent task launcher that can
   explicitly create a fresh branch and worktree from `origin/main`. Inspect
   its help rather than inventing flags. If no launcher can manage worktrees,
   create one with Git, using a unique descriptive name for each experiment:

   ```sh
   git -C /path/to/sandbox worktree add \
     -b experiment/counter-20261111-01 \
     /path/to/sandbox-worktrees/counter-20261111-01 origin/main
   ```

   Choose an unused branch and sibling directory; never use force, reset an
   existing branch, or overwrite a worktree. Start a new agent task bound to
   that worktree with the available task runner. If tasks can only be opened
   manually, report the new branch and absolute worktree path so the user can
   open it as a new task. Do not implement the experiment in the main checkout.
   If a launcher fails with an uncertain outcome, inspect existing tasks and
   worktrees before retrying or falling back, to avoid duplicate experiments.

4. Install dependencies inside the new worktree with
   `pnpm install --frozen-lockfile`. Local framework linking is optional and
   must be configured separately in each worktree; follow
   [links/README.md](links/README.md). Do not copy another worktree's
   `node_modules` or assume its ignored checkout link is present. Keep all
   experiment changes and commits on the assigned branch. Report actual
   checks and leave the branch and worktree available for the user; do not
   remove them automatically.

## Report framework defects upstream

Report any framework defects encountered while constructing or verifying a
sandbox to [octane-xplat/octane-xplat](https://github.com/octane-xplat/octane-xplat/issues).
This applies even when a local workaround lets the sandbox proceed.

Before filing, search both open and closed upstream issues for the same
symptoms, affected APIs, and error messages, and read likely matches. If an
existing issue covers the defect, reference it in the sandbox's handoff and
add only useful new reproduction details to that issue; do not file a duplicate.
Otherwise, create an upstream issue with a minimal reproduction, expected and
actual behavior, affected platforms, framework versions or checkout commit,
and relevant sanitized logs. Distinguish confirmed defects from suspected ones.
Include the upstream issue link in the sandbox's handoff. If reporting is
blocked, state the blocker and preserve the details needed to file it.

## Framework versions

Keep framework/compiler/native tool pins in the supplied `catalog:xplat`.
Upgrade the version set and patches together, then run the app's checks.
Within a multi-package workspace, upgrade covers all packages. Preserve
app-specific dependencies and reconcile custom-patch conflicts before retrying:

```sh
pnpm dlx @octane-xplat/cli@latest upgrade --check
pnpm dlx @octane-xplat/cli@latest upgrade
pnpm xplat doctor
pnpm typecheck
```

## JSX types

The app's `tsconfig.json` selects shared native JSX types. Browser JSX leaves
select DOM types on their first line; keep runtime imports from `octane`:

```tsx
/** @jsxImportSource @octane-xplat/jsx/dom */
export function BrowserMessage() {
  return <p>Ready</p>
}
```

Native leaves can explicitly select the same default with
`/** @jsxImportSource @octane-xplat/jsx */`. Do not replace it with a renderer
pragma. The facade supplies types; Vite still selects the platform renderer.

## App testing

The starter includes managed runners, sample tests, configuration, and scripts
for its enabled platforms. Adapt the samples to the app and run the relevant
commands:

```sh
pnpm test:web
pnpm test:ios --device DEVICE_UDID
pnpm test:android --device DEVICE_SERIAL
```

Only commands for enabled platforms are added. Web tests use jsdom; phone
tests need a selected simulator or device. Report targets actually run and
distinguish document checks from browser layout or OS input checks. See the
[testing guide](https://octane-xplat.goddardai.org/testing#add-automated-tests).

## Stable automation targets

```tsx
import { Button } from '@octane-xplat/ui'

export function AddItem() {
  return <Button testID="packing.add-item" label="Add item" accessibilityLabel="Add item" />
}
```

Assign optional semantic `testID` names to meaningful controls and asserted
state as you build: `packing.add-item`, `profile.name`,
`packing.item.${item.key}.open`. Keep names unique among mounted targets,
stable across localization, and based on durable repeated-item keys rather
than array positions. Preserve `id` values, useful accessibility labels and
roles. Do not put IDs on every decorative child or expose personal data.
Inputs target their editable host; overlays target mounted content. Verify
forwarding when composing another component; inherited types alone do not
promise platform support. See [qualified hosts and mappings](https://octane-xplat.goddardai.org/test-identifiers).

Argent is optional AI-agent device/browser control through MCP, with no app
runtime dependency. Use [official setup](https://docs.swmansion.com/argent/docs/fundamentals/installation/)
and the [qualified local recipe](https://octane-xplat.goddardai.org/argent)
(version 0.27.0). Prefer stable IDs for reliable targeting while keeping
spoken accessibility semantics. Discovery and replay have different native
prerequisites. Chromium prefers DOM `id` over `data-testid` when both exist.
The recipe states the actual iOS/Android/Chromium scope and limits; do not
infer AppKit, physical-device, or arbitrary typing support.

## Sandbox package manager and local framework

Use pnpm 11.24.0 for this app. Run installs explicitly after dependency edits.
The default install uses published packages. For an optional local Bun-based
Octane Xplat checkout, follow [links/README.md](links/README.md).
`pnpm dev:octane /path/to/octane-xplat` creates an ignored link and installs
local framework packages without saving machine paths to the manifest or lockfile.
NativeScript scripts skip automatic installs so they preserve that choice.

Use `createRoot(container).render(App)` at web roots. This is Octane's
component-body overload and keeps the starter independent of the shared
JSX facade's native element type during local-checkout typechecking.

Use `pnpm dev:published` to switch back. It removes the sandbox’s generated
`node_modules` before a frozen install, clearing stale nested pnpm links.
