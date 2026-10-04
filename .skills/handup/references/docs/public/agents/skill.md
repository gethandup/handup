# Install the handup agent skill

Install handup's approval workflow and complete offline user documentation into a supported agent's skill directory. This installs **instructions**, not the handup binary, daemon, MCP configuration or native permission hooks.

## Private GitLab installation

The repository is private. You need Node.js 22.20 or newer, Git, and existing SSH access to `ariel-frischer/handup` on GitLab. The command uses your normal Git/SSH authentication; it does not require publishing handup to npm.

Run from the project where the agent should use handup:

```sh
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add git@gitlab.com:ariel-frischer/handup.git \
  --full-depth --skill handup --agent claude-code codex cursor --yes
```

Replace the agent names with the targets you use. Add `--global` for user-level installation instead of project-local installation. The leading `--yes` belongs to npx; the trailing one belongs to the skills installer.

To target every agent registered by this version of the installer, use a project-local install:

```sh
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add git@gitlab.com:ariel-frischer/handup.git \
  --full-depth --skill handup --agent '*' --yes
```

Quote `'*'` so the shell does not expand it. “Every agent” means the installer's
supported targets, not every possible agent runtime. Wildcard selection skips
targets whose project directory does not exist; explicitly name your agents to
create their installation directories. Some targets have no global installation
directory; use explicit targets rather than `--global --agent '*'`.

To inspect discovery without installing:

```sh
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add git@gitlab.com:ariel-frischer/handup.git \
  --full-depth --skill handup --list
```

`--full-depth` ensures `.skills/handup` is discovered even if the repository later contains skills in another conventional directory. In skills 1.7.0, use the exact SCP-style `git@gitlab.com:...` source shown above: the superficially equivalent `ssh://git@gitlab.com/...` form is rewritten to HTTPS and can lose the working SSH authentication path.

### GitLab credentials and local fallback

A working `glab` API login does **not** necessarily configure Git HTTPS clone credentials for `npx skills`. Existing GitLab SSH access is the verified private-source path. Do not put a token in an install URL or copy credentials into the skill.

If you already have an authenticated clone, install from it without any remote credential lookup:

```sh
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add ./handup \
  --full-depth --skill handup --agent claude-code codex cursor --yes
```

Here `./handup` is the checkout directory; from inside that checkout use `.` instead. `glab repo clone ariel-frischer/handup` is another way to obtain a clone using your existing GitLab setup; install from the resulting local directory.

## What the installed skill includes

The entire skill directory is installed, including:

- `SKILL.md`: approval/denial workflow, preview recipes, exit codes and topic routing.
- `references/index.md`: inventory of every bundled public guide and machine contract.
- `references/llms-full.txt`: full public guide text in one offline-readable file.
- `references/docs/public/`: getting started, all agent integrations, desktop/mobile, remote access, relay, rules, lifecycle hooks, OpenAPI and request/decision/event JSON schemas.
- `references/examples/`: runnable request examples and their preview assets.

Load only the relevant reference for the current task. The full documentation is available offline; it does not have to be inserted into every agent prompt. Copying only `SKILL.md` loses the reference bundle.

For an agent the skills CLI does not register, copy the **whole** `.skills/handup` directory into that agent's documented skill-loading directory, or provide its workflow/reference files as instructions. `omp` and `jcode` are not valid `--agent` IDs in skills 1.7.0. A shell-capable agent can use the installed handup CLI; an MCP-capable agent can call configured handup tools. Neither path implies native tool interception.

Install the binary separately using [getting started](../index.md). Then configure [MCP](mcp.md), or the appropriate native adapter: [Claude Code](claude-code.md), [Codex](codex.md), [omp](omp.md). Installing the skill alone does not configure any of these. If neither CLI nor MCP is available, the agent must stop consequential work and report missing setup, not proceed without approval.

## Future public source URL

**Only after a separately authorized change makes the repository public**, replace the SSH source with the public GitLab HTTPS URL:

```sh
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add https://gitlab.com/ariel-frischer/handup \
  --full-depth --skill handup --agent claude-code codex cursor --yes
```

The skill name, package layout and agent flags stay the same. No handup npm package is needed: npx runs the public `skills` installer, which fetches the Git repository. This command is a future cutover example, not a claim that anonymous installation works while handup remains private. Anonymous discovery/install must be verified after the visibility change. If the public repository moves, substitute its actual new URL.

## Maintainers: regenerate the bundle

```sh
make docs-skill
```

This documentation-only target uses Python, copies the checked-in public contracts, and does not compile Rust or start a daemon. `references/` is generated; edit canonical `docs/public` guides instead. Commit the refreshed bundle with source-document changes so remote skill installs receive current documentation.

After Rust model/API changes, the existing `make docs` workflow regenerates the machine contracts and the portable bundle. Follow the repository's CI build policy; do not use a local release/desktop/mobile build to refresh skill prose.

Installer behavior is pinned to [skills 1.7.0](https://github.com/vercel-labs/skills/tree/7407f3893ad4dceab546ac002c3ef806e4000c73), published 2026-09-17. See its [supported agents and source formats](https://github.com/vercel-labs/skills/blob/7407f3893ad4dceab546ac002c3ef806e4000c73/README.md). Private authenticated discovery was verified on 2026-09-30; that is distinct from anonymous public access or native-hook enforcement.
