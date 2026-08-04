# ai-sandbox

A macOS **Seatbelt** (`sandbox-exec`) profile for sandboxing AI coding agents -
Claude Code, OpenCode, Codex, Gemini CLI, Qwen, Aider, and friends.

Tested on **macOS 26.5 (Tahoe)**. `sandbox-exec` is marked deprecated by Apple,
but the underlying Seatbelt subsystem is fully functional and remains the
standard macOS process sandbox.

## What it does

Runs an agent process (and all of its child processes - `bash`, `git`, `node`,
…) inside a Seatbelt sandbox where:

- **The whole disk is readable.**
- **Writes are allowlisted** - the agent can only write to:
  - the project directory you launch it in (`WORKSPACE`)
  - AI config dirs (`~/.claude`, `~/.codex`, `~/.config/{openai,anthropic,…}`,
    `~/.opencode`, `~/.gemini`, `~/.qwen`, …)
  - caches (`~/Library/Caches`, `~/.cache`, `~/.cargo`, `~/.gradle`, `~/.m2`,
    `~/.npm`, …)
  - toolchains (`~/.volta`, `~/.nvm`, `~/.pyenv`, `~/go`, `~/.bun`, `~/.deno`, …)
  - temp + devices (`/private/tmp`, `/dev/null`, …)
- **Secret stores are read-only** - readable (so git-over-ssh, AWS SDKs, etc.
  work) but never writable:
  `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.docker`, `~/.kube`, `~/.config/gcloud`,
  `~/.azure`, `~/.config/gh`, `~/.netrc`, `~/.npmrc`, `~/.pypirc`,
  `~/.gem/credentials`, `~/Library/Keychains`.
  Exception: `~/.ssh/known_hosts` is writable (so ssh can record new host
  keys); private keys and `~/.ssh/config` stay read-only.

**Threat model: anti-tampering, not anti-exfiltration.** Reads are wide open;
the goal is to stop the agent from *modifying* things it shouldn't, not to
build an airtight data-leak boundary.

## Install

Clone and run the installer:

```sh
git clone https://github.com/ymy88/ai-sandbox.git
cd ai-sandbox
./install.sh
```

`install.sh` detects the repo directory and writes a `sandboxed` shell function
into your `~/.zshrc` (or `~/.bashrc`) that points at `ai-sandbox.sb` in the repo.
Nothing is copied to `~`. Re-run it any time to refresh; uninstall with
`./install.sh --remove`.

Then start a new shell (or `source ~/.zshrc`) and:

```sh
cd ~/your/project
sandboxed claude          # or opencode / codex / gemini / aider / ...
```

`WORKSPACE` is the directory you launch from - the only project tree the agent
may edit. Child processes inherit the sandbox, so a `bash` the agent spawns is
restricted the same way.

### No-install alternative

Run the wrapper script directly, without touching your rc:

```sh
cd ~/your/project
/path/to/ai-sandbox/sandboxed claude
```

### Read-only / analyze mode

For query/analysis work where the agent should **not** modify the code, use the
stricter `sandboxed-ro` (profile: `ai-sandbox-ro.sb`). It keeps reads wide open
and network allowed, but makes the **project dir (incl. `.git`) read-only** and
locks down toolchain installs and global git config, while still letting the
agent write its own session/config, caches, and temp.

```sh
cd ~/your/project
sandboxed-ro claude          # analyze only; cannot edit the project or .git
```

`git log/diff/show/blame` work; `commit/checkout/stash/fetch/pull`, file edits,
and `npm install` into the project all fail. Logins (`npm login`, `gh auth
login`, …) still fail - run those outside, the agent reads tokens inside.

## Caveats (please read)

- **Network is allowed** (the agent must reach its model API). This is *not* an
  egress firewall; a prompt-injected command could still phone home.
- **Login operations fail inside the sandbox** - `npm login`, `gh auth login`,
  `pip login`, `aws configure`, `gcloud auth` all try to *write* credential
  files, which are read-only. Run those outside the sandbox; the agent can then
  *read* the resulting tokens inside.
- **SSH host-key rotation** (replacing an existing entry) uses tmpfile+rename
  and needs write access to `~/.ssh/` itself, which is blocked. Adding a *new*
  host works (append to `known_hosts`); run key rotations outside the sandbox.
- **macOS Keychain** writes via Mach IPC aren't blocked (blocking mach breaks
  too much). Direct file reads of `~/Library/Keychains` are allowed.
- **`brew install` / global installs** are blocked by default (`/opt/homebrew`,
  `/usr/local` are not writable). Uncomment the relevant lines in the profile
  if you need them.
- `sandbox-exec` is deprecated by Apple; if a future macOS removes it, this
  profile stops working. For a stronger boundary, run the whole agent in a
  container/VM (see Pi's
  [containerization docs](https://github.com/earendil-works/pi-mono)).

## Files

- [`ai-sandbox.sb`](ai-sandbox.sb) - the Seatbelt profile (heavily commented;
  tweak the allow/deny lists to taste)
- [`ai-sandbox-ro.sb`](ai-sandbox-ro.sb) - stricter read-only/analyze profile
  (project + toolchains read-only; AI session/caches writable)
- [`install.sh`](install.sh) - installs the `sandboxed` and `sandboxed-ro` shell functions
- [`sandboxed`](sandboxed) - self-locating wrapper script (no-install option)
- [`sandboxed-ro`](sandboxed-ro) - self-locating wrapper for the read-only profile

## License

MIT - see [LICENSE](LICENSE).
