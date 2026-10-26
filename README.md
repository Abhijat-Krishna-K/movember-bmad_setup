<div align="center">

# Movember BMad Setup

**One shared home for BMad workflows across Movember repositories.**

Plan with clarity · Build with context · Keep every repo in sync

[Explore the workflow](#whats-inside) · [Get started](#getting-started) · [BMad documentation](https://docs.bmad-method.org/)

</div>

---

## What is this?

This repository hosts a local [BMad Method](https://docs.bmad-method.org/) installation and its agent skills for Movember projects. It is a **workflow toolkit, not an application**: use it to move from an idea through research, requirements, architecture, implementation, review, and testing. A Windows PowerShell helper can share the same setup with neighboring `movember-*` Git repositories, so the skills have one place to live.

## What's inside

| Area | What you get |
| :--- | :--- |
| **Discovery & planning** | Brainstorming, research, product briefs, PRDs, UX design, architecture, epics, stories, and sprint planning. |
| **Delivery & quality** | Build workflows, code/document review, walkthroughs, QA test generation, and retrospectives. |
| **Specialist agents** | Mary (analyst), John (product manager), Sally (UX designer), Winston (architect), and Amelia (developer). |
| **Guidance & customization** | `bmad-help` recommends the next step; team and personal overrides tailor the installed workflows. |
| **Repo sharing** | `scripts/link-repos.ps1` links available skills and BMad files into sibling repositories without copying the whole installation. |

### Repository map

```text
.agents/skills/       BMad skills exposed to the coding assistant
_bmad/               Installed core/BMM configuration, catalogs, and scripts
_bmad/custom/        Team-level configuration overrides
_bmad-output/        Generated planning and implementation artifacts
scripts/             Windows repo-linking helper and smoke test
```

## Getting started

1. Open this repository in an assistant that supports the installed `.agents/skills` skills.
2. Ask for `bmad-help` if you are unsure where to begin, or invoke a skill directly (for example, `bmad-product-brief`, `bmad-prd`, `bmad-architecture`, or `bmad-build`).
3. Keep generated work in `_bmad-output/`; check `_bmad/config.toml` for the configured artifact locations.

To make the shared setup available in neighboring projects, run the helper from **Windows PowerShell** at the repository root:

```powershell
.\scripts\link-repos.ps1
.\scripts\link-repos.ps1 -Repos movember-android
```

Without `-Repos`, the helper discovers sibling `movember-*` folders containing a Git checkout at the folder root or in `Code/`. It creates junctions for available `.agents/skills`, `.claude/skills`, and `_bmad` directories, copies available Copilot agent profiles and Claude settings where appropriate, and records managed paths in each target repo's local Git exclude file. Existing real folders and unmanaged files are left alone.

To detach **only paths managed by this helper**, run:

```powershell
.\scripts\link-repos.ps1 -Unlink
```

The helper needs Windows PowerShell and Git. If optional Copilot generation files are present, linking also calls `uv` with Python 3.11+. You can run its isolated smoke test with `.\scripts\test-link-repos.ps1`.

## Customize safely

`_bmad/config.toml` is installer-managed and can be overwritten on reinstall. Put shared overrides in `_bmad/custom/config.toml` and personal overrides in `_bmad/custom/config.user.toml` instead. For skill or agent behavior changes, use `bmad-customize`.

---

<div align="center">

Built on the [BMad Method](https://docs.bmad-method.org/) · Maintained as a shared Movember workflow setup

</div>
