# Give your agent the handup workflow

Agents need the approval contract and usage instructions, not the handup
application source. Install the compiled program separately using
[downloads and releases](../downloads.md), then configure [MCP](mcp.md) or the
appropriate native adapter: [Claude Code](claude-code.md), [Codex](codex.md),
[Cursor](cursor.md) or [omp](omp.md).

## Use the installed program

For Claude Code, print the instruction snippet:

```sh
handup prompt --agent claude
```

Paste the output into your project's agent instructions. `handup prompt --help`
lists available agents. Printing instructions does not install the daemon,
configure MCP or intercept native permissions; follow the integration guide
for those steps.

An agent with CLI access can call handup commands; an MCP client can call its
configured tools. If neither is available, it must stop consequential work and
report missing setup—not proceed without approval.

## Install the skill bundled with handup

If handup is installed, prefer its bundled copy. It needs no Node.js, Git or
network access, and always matches the installed program's version:

```sh
handup skill install                  # ~/.agents/skills/handup
handup skill install --agent claude   # ~/.claude/skills/handup
handup skill install --agent codex    # $CODEX_HOME/skills/handup (default ~/.codex)
handup skill install --project        # ./.agents/skills/handup; combine with --agent
handup skill install --dir PATH       # any other skill directory
```

`--dry-run` prints the planned change without writing. A `.handup-skill` marker
records the installed version; rerun `handup skill install` after upgrading
handup to refresh it. An existing directory without the marker is left alone
unless you pass `--force`. `handup skill uninstall` (same location flags)
removes only marked directories.

## Or install the skill from GitHub

The skill installs handup's approval workflow and complete offline user documentation into a supported agent's skill directory. It is published from [gethandup/handup](https://github.com/gethandup/handup), which holds handup's docs, this skill and examples (not the application source). You need Node.js 22.20 or newer and Git. No handup npm package is needed: npx runs the `skills` installer, which fetches the Git repository.

Run from the project where the agent should use handup:

```sh
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add gethandup/handup \
  --skill handup --agent claude-code codex cursor --yes
```

Replace the agent names with the targets you use. Add `--global` for user-level installation instead of project-local installation. The leading `--yes` belongs to npx; the trailing one belongs to the skills installer.

**The repository is private for now.** The installer clones `https://github.com/gethandup/handup.git` with your normal Git setup, so your Git must be able to clone it over HTTPS, for example after `gh auth setup-git`. With GitHub SSH access instead, use the SCP-style source `git@github.com:gethandup/handup.git` in place of `gethandup/handup`. Do not put a token in an install URL or copy credentials into the skill. Anonymous installation must be verified once the repository is public.

To target every agent registered by this version of the installer, use a project-local install:

```sh
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add gethandup/handup \
  --skill handup --agent '*' --yes
```

Quote `'*'` so the shell does not expand it. “Every agent” means the installer's
supported targets, not every possible agent runtime. Wildcard selection skips
targets whose project directory does not exist; explicitly name your agents to
create their installation directories. Some targets have no global installation
directory; use explicit targets rather than `--global --agent '*'`.

To inspect discovery without installing:

```sh
DO_NOT_TRACK=1 npx --yes skills@1.7.0 add gethandup/handup --skill handup --list
```

## What the installed skill includes

The entire skill directory is installed, including:

- `SKILL.md`: a short router with the approval/denial workflow, what never to self-approve, MCP and CLI essentials, exit codes and a read-on-demand reference table.
- `references/index.md`: inventory of every bundled public guide and machine contract.
- `references/llms-full.txt`: full public guide text in one offline-readable file.
- `references/docs/public/`: getting started, all agent integrations, desktop/mobile, remote access, relay, rules, lifecycle hooks, cookbook, OpenAPI and request/decision/event JSON schemas. Pages are text only; website banner images are omitted.
- `references/examples/`: runnable request examples and their preview assets.

Load only the relevant reference for the current task. The full documentation is available offline; it does not have to be inserted into every agent prompt. Copying only `SKILL.md` loses the reference bundle.

For an agent the skills CLI does not register, run `handup skill install --dir PATH` with that agent's documented skill-loading directory, copy the **whole** skill directory there, or provide its workflow/reference files as instructions. `omp` and `jcode` are not valid `--agent` IDs in skills 1.7.0. A shell-capable agent can use the installed handup CLI; an MCP-capable agent can call configured handup tools. Neither path implies native tool interception. Installing the skill alone does not install the binary or configure MCP or native adapters.

## Public documentation, private application source

The usage guides and machine contracts are readable independently of the
application repository. The [MCP guide](mcp.md) and [shell/CI guide](shell-ci.md)
describe the approval contract: wait for a human decision, bind the exact action
to the returned content hash, and treat denial as a normal answer. Do not request
application source access merely to install agent instructions.

Installer behavior is pinned to [skills 1.7.0](https://github.com/vercel-labs/skills/tree/7407f3893ad4dceab546ac002c3ef806e4000c73), published 2026-09-17. See its [supported agents and source formats](https://github.com/vercel-labs/skills/blob/7407f3893ad4dceab546ac002c3ef806e4000c73/README.md). Authenticated installation from GitHub (`gethandup/handup`) was verified on 2026-10-03; that is distinct from anonymous public access or native-hook enforcement.
