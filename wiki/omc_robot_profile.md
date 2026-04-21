# OMC Robot Profile — Planner/Servant Role-Scoped Distillation

> Canonical profile document for the robot parent (`~/robot/`) + children. Authoritative for AC-1..AC-8 of plan `robot-omc-role-scoped-distillation`.
> Source plan: `~/robot/datafactory/.omc/plans/robot-omc-role-scoped-distillation-plan.md` (iter 2 + session-2 amendments AM-1..AM-7).
> Status: Phase A in progress (sections 1,2,3,4,5,9 populated; 6,7,8,10 stubbed).

---

## 1. Planner Tier — Tools, MCPs, Skills

**Role.** Main Claude Code session. Owns persistence (notepad, wiki, shared memory, project memory), git commits, cross-domain orchestration, NotebookLM CLI, research.

**MCPs (loaded at `~/robot/datafactory/` cwd via `.mcp.json`).**
- `isaac-sim` — Isaac Sim 4.5.0 control (port 8766, TCP listener inside Isaac container). **Planner-level discipline (AM-4): do NOT invoke directly — delegate to `isaac-operator`.**
- `ros-mcp` — ROS 2 / rosbridge (port 9090 WebSocket). **Discipline: delegate to `ros2-operator`.**
- Plugin MCPs (always-on via OMC plugin layer): `context7` (`mcp__plugin_context7_context7__resolve-library-id`, `mcp__plugin_context7_context7__query-docs`), `github-mcp-server`, `oh-my-claudecode` tooling.

**Native Claude Code tools.** `Bash`, `Read`, `Edit`, `Write`, `Grep`, `Glob`, `WebSearch`, `WebFetch`, `Task` (Agent), `TaskCreate`/`TaskUpdate`/`TaskList`, `ToolSearch`.

**OMC skills (planner uses).**
`wiki`, `remember`, `external-context`, `ralplan`, `plan`, `verify`, `cancel`, `learner`, `skillify`, `trace`, `deep-interview`, `autopilot`, `team`, `ultrawork`, `ralph`.

**Superpowers skills (planner uses).**
`test-driven-development`, `receiving-code-review`, `finishing-a-development-branch`, `using-git-worktrees`, `requesting-code-review`, `verification-before-completion`, `systematic-debugging`, `writing-plans`, `executing-plans`, `brainstorming`.

**NotebookLM CLI.** Planner-only (AC-7). Active notebook ID `7cf81435-cc9d-419e-8dfa-fe88c02dfa42`. Session auth at `~/.notebooklm/storage_state.json`. Quota ~50 queries/day — see §3.

---

## 2. Servant Agent Matrix

All servants live at **user scope** (`~/.claude/agents/*.md`) per AM-2. Discoverable from every robot child. Authored in Phase A-1 (this document's commit).

| Agent | Model | `cwd` (inherited from planner) | MCP access (runtime-scoped) | `disallowedTools` category | Spawn via |
|---|---|---|---|---|---|
| `isaac-operator` | `sonnet` | `~/robot/datafactory/` | `mcp__isaac-sim__*` only (ros-mcp enumerated in deny-list) | Write, ros-mcp enumerated, context7, github writes, web, all persistence (notepad/wiki/shared_memory/project_memory) | `Task(subagent_type="isaac-operator", ...)` |
| `ros2-operator` | `sonnet` | `~/robot/datafactory/` | `mcp__ros-mcp__*` only (isaac-sim enumerated in deny-list) | Write, isaac-sim enumerated, context7, github writes, web, all persistence | `Task(subagent_type="ros2-operator", ...)` |
| `docker-operator` | `haiku` | planner's cwd at invocation | None (all MCPs in deny-list) | Write, Edit, all MCPs enumerated, web, all persistence | `Task(subagent_type="docker-operator", ...)` — **default off (AM-7)**, on-demand |

### Hardened Return-Value Contract (H7)

Every servant MUST emit exactly these two fenced blocks at end of response:

```
## Result
```json
{"status": "success|fail", "artifact_paths": ["..."], "next_action": "...", "domain_findings": {...}}
```

## Evidence
<free-form markdown: commands run, outputs, observations, planner-actionable follow-ups>
```

Planner parses `## Result` JSON via a one-line extractor; `## Evidence` is human-read only. If JSON block is missing or unparseable, planner re-prompts once; second failure → escalate.

### Discipline rules (AM-4)

- Planner MUST NOT invoke `mcp__isaac-sim__*` / `mcp__ros-mcp__*` directly — always delegate to the matching operator.
- Violations audited end of each phase via session transcript. ≥1 violation: log to §Discipline Violations, revisit-trigger counter +1. 2 violations total → migrate to method-Y (`omc-teams` tmux panes, AM-5).
- Servants never: modify `wiki/`, write `notepad_*`, `shared_memory_*`, `project_memory_*`, `git commit`, spawn sub-agents.

---

## 3. NotebookLM CLI — Planner-only

**Active notebook ID**: `7cf81435-cc9d-419e-8dfa-fe88c02dfa42`
**Session auth**: `~/.notebooklm/storage_state.json` (expires ~weekly)
**Quota**: ~50 queries/day

**Rule**: Only the planner tier invokes `notebooklm` CLI. Servants never — they do not have the auth file in their tool scope and cannot spawn `Bash` with notebooklm in their allowed set during future tightening.

Canonical commands (full 5-command block + quota/re-auth procedure populated in Phase C-2):

```bash
python3 -m notebooklm status
python3 -m notebooklm use <notebook-id>
python3 -m notebooklm ask "<question>"
python3 -m notebooklm source add --url <url>
python3 -m notebooklm source add-research <query>
```

---

## 4. 3-Layer Structure (from setup-guide §11)

```
~/robot/                  ← Layer 1: Parent (template + cross-child knowledge)
├── wiki/                 ← global wiki (this file + lessons)
├── AGENTS.md             ← children catalog (fenced bootstrap entries)
├── CLAUDE.md / AGENTS.md ← planner persona
├── .claude/              ← parent-scope project settings
├── isaac-sim-mcp/        ← symlink → ~/Desktop/Project/isaac-sim-mcp (R8 mitigation)
├── scripts/bootstrap-child.sh
└── datafactory/          ← symlink → ~/Desktop/Project/DATAFACTORY
    ├── .mcp.json         ← Layer 2: Child MCP scope (isaac-sim, ros-mcp)
    ├── .claude/          ← child-scope settings (SessionStart + PostCompact hooks)
    ├── wiki/             ← child-specific lessons
    └── .omc/             ← plans, specs, state
~/.claude/agents/         ← Layer 3: Servant definitions (user scope, AM-2)
├── isaac-operator.md
├── ros2-operator.md
└── docker-operator.md (default off, AM-7)
```

**Isolation semantics.**
- Layer 1 sees all children (catalog via AGENTS.md + fenced markers).
- Layer 2 `.mcp.json` scopes MCPs per child — switching cwd switches MCP set.
- Layer 3 is session-global (hot-load caveat: see §9) — same servants used from any child.

---

## 5. Portability — `bootstrap-child.sh`

**Invocation**: `~/robot/scripts/bootstrap-child.sh <child-name> [--dry-run]`

**Checklist (what the script MUST produce, verified by AC-6)**:
1. `<child>/.claude/settings.json` with both `SessionStart` and `PostCompact` hooks referencing `PARENT=$HOME/robot`.
2. `<child>/.mcp.json` seeded with `{"mcpServers":{}}` (empty — child declares own MCPs).
3. `<child>/wiki/INDEX.md` stub.
4. Parent `~/robot/AGENTS.md` gains a Children entry wrapped in fenced markers:
   ```
   <!-- BOOTSTRAP_BEGIN:<child> -->
   - `<child>/` — <one-line description>
   <!-- BOOTSTRAP_END:<child> -->
   ```
5. MCP connectivity is **out of scope** (spec L62) — the child's team plugs MCPs post-bootstrap.

**Cleanup** (fence-aware — M8 fix):
```bash
sed -i '/<!-- BOOTSTRAP_BEGIN:<child> -->/,/<!-- BOOTSTRAP_END:<child> -->/d' ~/robot/AGENTS.md
rm -rf ~/robot/<child>
```

**Never**: mix symlink and real path within a single Agent invocation (R8).

---

## 6. Token Budget (AC-1)

**Status**: `TBD (Phase D-1)`. Methodology already fixed per B4: extract `additionalContext` field only from SessionStart hook output, measure bytes via `wc -c`. Baseline + post-distillation delta recorded here.

| Snapshot | `additionalContext` bytes | Notes |
|---|---|---|
| Pre-distillation (before Phase A commit) | TBD | Reconstruct via `git stash`/ancestor commit read |
| Post-distillation (after Phase D commit) | TBD | Goal-direction: `< 5_000` chars. Directional target (AC-3 owns pass/fail gate). |
| Δ | TBD | |

---

## 7. Agent Call Cost + Token Methodology (AC-2 — Option Beta)

**Status**: `TBD (Phase D-2)`. Absolute target: `mean_tokens_per_call ≤ 8_000` across N≥5 canned probes per servant type, 95% CI reported.

| Servant | Probe | Mean tokens | 95% CI | Ceiling verdict |
|---|---|---|---|---|
| `isaac-operator` | `get_scene_info` + 10-line `execute_script` printing `isaacsim.__version__` | TBD | TBD | TBD |
| `ros2-operator` | `connect_to_robot` + `get_topics` | TBD | TBD | TBD |

### Token Methodology (TBD Phase D-2)

- Instrumentation exact location: `TBD (session JSONL path / hook log entry field name)`.
- N per probe: ≥5.
- Confidence interval method: `TBD (bootstrap / t-distribution)`.
- Payload-adjustment rule: if first probe mean > 8k but explained by domain payload (Isaac scene dump), raise ceiling to `observed + 10%` and log rationale in-table.

---

## 8. Alternatives Audit (AC-8)

**Status**: `TBD (Phase C-3)`. Required rows:
- Isaac MCP stay vs alternatives (`NVIDIA-Omniverse/IsaacSim-MCP`, `omni.kit.exec_script` thin wrapper, Robosynx / Isaac Monitor).
- ros-mcp stay vs alternatives (`robotmcp/ros-mcp-server`, `lpigeon/ros-mcp-server`, direct rclpy, `hijimasa/isaac-ros2-control-sample`).
- ≥3 new skills/MCPs shortlist (bucketed `adopt / trial / watch`): `superpowers:test-driven-development` (adopt), `oh-my-claudecode:visual-verdict` (trial), `oh-my-claudecode:configure-notifications` (trial), Exa MCP (trial), Docker MCP Toolkit (skip — Critical-3), filesystem-mcp per-child (watch).

Cross-checks queued for Phase C-3:
- NVIDIA forum MCP tutorial diff vs `wiki/mcp_lessons.md` §MCP extension 활성화 (via `document-specialist`).
- `context7.resolve-library-id("isaac-sim")` + `("ros2")` coverage audit.

---

## 9. Scope Schema Branch Record (A-0 outcome — **2026-04-21**)

**Chosen schema**: **γ (`disallowedTools:`)** single-schema. β+γ hybrid rejected (AM-6). Decision drivers: matches OMC shipped convention (8/8 shipped agents), zero drift, maximum portability, token-efficient frontmatter; β+γ's implicit-grant hardening is covered by §10 Version Audit Log.

**A-0 empirical outcomes**:

1. **Static evidence (AM-1)**: OMC shipped agents 8/8 (`architect`, `analyst`, `critic`, `scientist`, `code-reviewer`, `security-reviewer`, `document-specialist`, `explore`) use `disallowedTools: Write, Edit` — bare tool names, no wildcards, no MCP-prefixed entries. This is the ship-canonical pattern.

2. **Hot-load probe finding** (NEW — logged in `mcp_lessons.md` §2026-04-21): **user-scope agent files are NOT auto-discovered mid-session**. Writing `~/.claude/agents/*.md` and immediately spawning via `Task` returns `Agent type 'X' not found`. `/reload-plugins` reloads plugins/skills/hooks but not user-scope agents. Servants become available only after session restart.

   **Implication for AM-2**: user-scope is correct for cross-child portability, but any servant edit requires a session restart before it takes effect. Must be documented in §Troubleshooting (stub, Phase D).

3. **Wildcard enforcement (untested)**: no OMC shipped agent uses wildcards or MCP prefixes in `disallowedTools`. Our servants enumerate ~20 specific tool names per servant. If wildcard syntax (`mcp__ros-mcp__*`) had been used, enforcement would be empirically unverified. Current design uses explicit enumeration → safer at the cost of needing updates when MCPs add tools. Re-evaluated at next OMC minor bump via §10.

4. **Symlink MCP path assertion (A-0 step 8)**: `~/robot/isaac-sim-mcp` → `~/Desktop/Project/isaac-sim-mcp` symlink **created 2026-04-21**. `.mcp.json` relative path `../isaac-sim-mcp` now resolves consistently whether launched via symlink or real path. R8 mitigated.

5. **γ declarative enforcement — empirical status**: deferred to Phase B-2 (Case A/C servant invocation tests). Static evidence (point 1) is strong prior; empirical confirmation in next session after restart.

**Branch**: **γ** (single). Consequence: all servants in §2 use `disallowedTools:` only. If Phase B-2 Case A returns "silent" (no declarative refusal), escalate to AM-8 amendment and consider either β+γ hybrid or method-Y tmux isolation.

---

## 10. Version Audit Log (R4)

**Status**: `TBD — first entry at Phase D-3`.

Schema (per R4 mitigation):

| Date | OMC version | Schema branch | Template diff summary | Servant update action |
|---|---|---|---|---|
| TBD | v4.13.0 (plan authoring) | γ | baseline (this commit) | none |

On every OMC minor bump, run:
```bash
diff ~/.claude/agents/isaac-operator.md <(omc skill-creator print-template agent)
```
(or equivalent). Record diff summary here + whether servant update needed.

---

## Appendix — Cross-refs

- Plan: `~/robot/datafactory/.omc/plans/robot-omc-role-scoped-distillation-plan.md`
- Spec: `~/robot/datafactory/.omc/specs/deep-interview-robot-omc-role-scoped-distillation.md`
- Open questions: `~/robot/datafactory/.omc/plans/open-questions.md`
- Lessons: `~/robot/wiki/mcp_lessons.md`, `~/robot/wiki/isaac_sim_api_patterns.md`, `~/robot/wiki/ros2_bridge.md`, `~/robot/wiki/ecosystem_survey.md`
- Setup guide: `~/robot/datafactory/robot-dev-omc-setup-guide.md` §3–5, §11, §13h
- NotebookLM guide: `~/robot/datafactory/notebooklm-cli-guide.md`
