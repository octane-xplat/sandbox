# Use a local Octane Xplat checkout

The sandbox normally installs published packages. This optional workflow is for
trying framework edits before they are published. It follows Opals' explicit
pnpm-hook approach: the sandbox uses pnpm, while the framework checkout keeps
its own Bun package manager.

## Prepare and link

1. Prepare a current Bun-based framework checkout using its own `AGENTS.md`.
   Install its pinned Bun version first. From that checkout, install packages
   and build the CLI, lint engine, and declarations used by the sandbox:

   ```sh
   bun install --frozen-lockfile
   bun run turbo run build --filter=@octane-xplat/cli --filter=@octane-xplat/lint
   bun run turbo run typegen --filter=@octane-xplat/ui --filter=@octane-xplat/platform --filter=@octane-xplat/jsx --filter=@octane-xplat/workshop
   bun run turbo run build:go --filter=@octane-xplat/cli
   ```

   The last command needs the Go version pinned by that checkout. Build any
   additional package you add according to its own instructions.

2. From the sandbox folder, select the prepared checkout:

   ```sh
   pnpm dev:octane /absolute/path/to/octane-xplat
   ```

   This creates the ignored `links/octane-xplat` symlink. It installs the app's
   declared framework packages as local links, aligns external tooling and
   patches with the checkout, and leaves `package.json`, `pnpm-workspace.yaml`,
   and `pnpm-lock.yaml` unchanged. It also runs a frozen Bun install with scripts
   skipped in the checkout before and after linking, to restore dependencies
   that pnpm's hoisted install may disturb. It does not build framework packages.

3. Start the sandbox:

   ```sh
   pnpm dev
   ```

After updating the checkout, refresh the installation using the saved link:

```sh
pnpm dev:octane
```

A missing or invalid checkout produces an error. Selecting a different path
replaces only the existing symlink; an ordinary file or folder at that location
is preserved and must be moved by its owner.

## Return to published packages

```sh
pnpm dev:published
```

This removes only the sandbox’s generated `node_modules` folder and reinstalls
from its committed lockfile. A plain reinstall may leave stale nested links
from pnpm’s hoisted layout; use this command when switching back. The framework
checkout is untouched. If installation fails, rerun `pnpm install --frozen-lockfile`.

The ignored symlink can stay in place. A normal install never loads the hook.
Automatic installs before scripts and within NativeScript are disabled so they
do not unexpectedly replace local packages. Install explicitly after editing
dependencies, then rerun `pnpm dev:octane` if you want local packages.

## Scope and limits

Local mode uses the checkout's framework package list, catalogs, managed external
versions, overrides, package extensions, and patch set. The creator-owned
`patches/` snapshot is replaced in memory. Keep custom app patches in a separate
folder; a collision with checkout patches fails explicitly. Selected URL-based
Bun patches cannot be represented by pnpm and are rejected.

Lifecycle scripts are skipped in local mode. Prepare the checkout first and
check its instructions when adding packages that need installation steps.
Published installs retain the creator's normal build permissions. Older
pnpm-based framework checkouts are not supported by this helper.

The hook uses pnpm's documented
[`readPackage` and `updateConfig` hooks](https://pnpm.io/pnpmfile).
Run its checks from the sandbox folder:

```sh
pnpm test:links
```

Web roots use Octane's component-body form, `root.render(App)`. The starter's
JSX argument form can fail local-checkout typechecking when the shared facade
assigns a native element type to `App`; the component form works with both
published and linked packages without widening types.

```tsrx
/** @jsxImportSource @octane-xplat/jsx/dom */
import { createRoot } from 'octane'
import { App } from '../src/App.tsrx'

createRoot(document.getElementById('root')!).render(App)
```
