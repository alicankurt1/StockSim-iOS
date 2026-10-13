---
name: phase-wrap-up
description: Close a StockSim phase - verify, ask end-of-phase review questions, record corrected answers in NOTES.md, update PLAN.md and README progress, commit and push the phase branch. Use when the user says a phase is done, "fazı kapat", or "/phase-wrap-up".
---

# Phase wrap-up

Work on the current `phase-N/<topic>` branch. Never commit to `main`.

## 1. Check the work

- Run the `verify` skill. Do not continue while anything fails.
- Compare the phase's items in `PLAN.md` with what was built. List anything missing or moved to a later phase, and ask the user before marking it done or moving it.

## 2. Review questions (mentor mode)

- Ask 2–3 interview-style questions in Turkish about this phase. Cover:
  - at least one SOLID principle, and where exactly it was applied (file + type)
  - one Clean Swift / architecture, testing or UIKit-drawing concept from the phase
- **Wait for the user's answers.** Do not answer for them.
- Correct the answers kindly. Say what was right, what was missing, and give a short, sayable version.

## 3. Update the docs

- `NOTES.md` (Turkish): add or replace the `## Phase N` section. Each question as a bold line, followed by the corrected answer in the user's own words, kept short. No personal or company references (public repo).
- `PLAN.md`: tick the phase's checkboxes (`- [x]`).
- `README.md`: set the phase row to `✅ Done` and the next phase to `🚧 In progress` only when it starts.
- Demo (visual phases): if a clip or screenshot was recorded, place it under `docs/media/phase-N-<topic>.gif|png` and reference it from the README when it is a highlight.

These doc updates go in the **same commit**.

## 4. Commit and push

```bash
git add -A
git commit -m "Phase N: <summary>"
git push -u origin phase-N/<topic>
```

- Check `git status` before committing: nothing unintended (DerivedData, `.DS_Store`, `xcuserdata`).
- End the commit message with the attribution trailer required by the session.
- `gh` is not installed: do not try to open a PR. Give the user the compare link `https://github.com/alicankurt1/StockSim-iOS/compare/main...phase-N/<topic>` and a short PR description (English) to paste.

## 5. Hand-off

In Turkish, summarize in 3–5 lines: what the phase delivered, which SOLID principles appeared where, and what the next phase starts with.
