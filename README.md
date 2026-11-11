# Octane Xplat Sandbox

A small playground for trying [Octane Xplat](https://octane-xplat.goddardai.org/).
Clone it, change the starter screen, and experiment. This is a sandbox, so
experiments may change or disappear.

Scaffolded with the official `create-octane-xplat` creator, with web, iOS, and
Android enabled. The starter includes a counter and a light/dark theme toggle.

## Run in your browser

Install [Node.js](https://nodejs.org/) 22.22.2 or later and
[pnpm](https://pnpm.io/installation) 11.24.0 before starting. Run these commands in a terminal:

1. Clone the repository and enter its folder:

   ```sh
   git clone https://github.com/octane-xplat/sandbox.git
   cd sandbox
   ```

2. Install the packages:

   ```sh
   pnpm install --frozen-lockfile
   ```

3. Start the development server:

   ```sh
   pnpm dev
   ```

Open the local address printed in the terminal. Try the counter, then edit
`src/App.tsrx` and save to try a change. Shared styles live in `src/style.css`.
Press Ctrl+C in the terminal to stop the server.

If installation fails, resolve the error before starting the server. The
[framework setup guide](https://octane-xplat.goddardai.org/toolchain) covers
prerequisites and platform tools.

## Check your experiments

Run these commands from the sandbox folder:

```sh
pnpm lint
pnpm typecheck
pnpm test:web
pnpm test:links
pnpm build
```

The web test checks the counter using a simulated browser document (jsdom).
It does not check layout or phone behavior. The build command produces the
web app; it does not compile iOS or Android.

## Try iOS or Android

Phone runs need NativeScript's platform tools. Follow the
[framework setup guide](https://octane-xplat.goddardai.org/toolchain) first;
iOS requires macOS and Xcode, and Android requires the Android SDK and Java.
Use an existing device and pass its identifier explicitly:

```sh
pnpm dev:ios --device YOUR_IOS_DEVICE_UDID
pnpm dev:android --device YOUR_ANDROID_DEVICE_SERIAL
```

Replace each placeholder with your device's identifier. Phone tests use the
same explicit selection:

```sh
pnpm test:ios --device YOUR_IOS_DEVICE_UDID
pnpm test:android --device YOUR_ANDROID_DEVICE_SERIAL
```

## Use a local framework checkout (optional)

Normal installs use published packages. To test changes in a local Bun-based
Octane Xplat checkout, see [the local-link setup](links/README.md):

```sh
pnpm dev:octane /absolute/path/to/octane-xplat
```

This prepares dependencies; start the app separately with `pnpm dev`.
Restore published packages with `pnpm dev:published`.

## Work with a coding agent

Ask your agent to read `AGENTS.md` and `.agents/skills/xplat/SKILL.md` before
editing. They explain the framework's shared-code and platform rules. Keep the
creator's framework pins and patches together when upgrading:

```sh
pnpm dlx @octane-xplat/cli@latest upgrade --check
```

See the [framework documentation](https://octane-xplat.goddardai.org/) for
components, styling, navigation, and services.

## License

[MIT](LICENSE). Fork it and make it your own.
