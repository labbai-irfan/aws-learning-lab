# Repository Standards & Contribution Guide

These conventions keep all 13 phases consistent so a learner can predict where everything lives. Apply them to every new file and every new phase.

---

## 1. Folder naming

- Phase folders: **`NN-kebab-case`**, where `NN` is a **zero-padded, unique, linear** index (`01`–`13`).
- The number **is** the curriculum order — never reuse a number, never leave a gap.
- One concept per phase folder. If a phase grows too large, split it and renumber everything after it (update cross-links — see §6).

## 2. File naming (inside a phase)

Numbered, kebab-case, in the canonical **content-band order** below. Not every phase needs every band, but when a band is present it uses the canonical name:

| Order | Category | Canonical filename |
|---|---|---|
| 01–0x | Core + topic notes | `01-<topic>-core-concepts.md`, `02-…`, … |
| then | Architecture & diagrams | `NN-architectures.md` |
| then | Cost optimization | `NN-cost-optimization.md` |
| then | Security | `NN-security-guide.md` |
| then | Hands-on labs | `NN-labs.md` |
| then | Troubleshooting | `NN-troubleshooting.md` |
| then | Cheat sheet | `NN-cheatsheet.md` |
| then | MCQs (100) | `NN-100-mcqs.md` |
| then | Interview questions (100) | `NN-100-interview-questions.md` |
| then | Scenario questions (50) | `NN-50-scenario-questions.md` |
| then | Certification mapping | `NN-certification-notes.md` |
| last | Hands-on project | `project/` (one capstone) or `projects/NN-name/` (multiple) |

**Pick one canonical spelling and stick to it:**
- troubleshooting → `NN-troubleshooting.md` (not `-guide`, not `-handbook`)
- MCQs → `NN-100-mcqs.md` · interview → `NN-100-interview-questions.md` · scenarios → `NN-50-scenario-questions.md`
- cheat sheet → `NN-cheatsheet.md`
- Use `project/` (singular) for a single capstone; `projects/` only when there are genuinely ≥2.

> Tooling-heavy phases (e.g. CI/CD) may use `labs/`, `docs/`, and an `aws/` assets tree instead of flat numbered notes — this is the only sanctioned layout exception.

## 3. Every phase README must contain (in order)

1. Title: **`# Phase NN — <Name> …`** (the number must match the folder).
2. One-line summary (blockquote).
3. Who it's for + **prerequisites** (linked to the prior phase).
4. **Learning-path table** — every row links to a file **that exists**.
5. Topics covered.
6. A 60-second mental model (ASCII diagram).
7. What you'll build (project teaser).
8. Conventions legend + cost note.
9. Official references.
10. "Start with …" pointer to the first numbered file.

## 4. Learning objectives

Open each phase with a **"By the end you can…"** list of 3–6 measurable outcomes, and a prerequisites line linking the previous phase.

## 5. Symbol legend (use consistently)

💡 tip/insight · ⚠️ gotcha/common mistake · 🛠️ hands-on action · 💰 cost note · 🔒 security note · 🏗️ architecture decision.
Shell: `$` = normal user, `#` = root/sudo. CLI examples use **AWS CLI v2**. Placeholders in `<angle-brackets>`.

## 6. Links & renumbering

- Prefer **path-anchored** relative links whose target is the real folder path (e.g. a link to phase 07 ends in `../07-elb-autoscaling/README.md`) — this makes a future renumber a simple find-and-replace.
- If you renumber or rename a phase, update **all** cross-links and visible `Phase NN` labels. Verify with the link checker (§7).
- Don't hard-code a phase number in prose where a link will do.

## 7. Before you commit — checklist

- [ ] No broken relative links (run the checker below).
- [ ] No duplicate phase-number prefixes.
- [ ] README learning-path table matches the files on disk.
- [ ] New file follows the §2 naming + band order.
- [ ] Secrets/keys/`node_modules`/Terraform state are git-ignored (never commit `.env`, `*.pem`, `*.tfstate`).

**Broken-link checker (PowerShell):**
```powershell
$root = (Get-Location).Path
Get-ChildItem -Recurse -File -Filter *.md | Where-Object { $_.FullName -notmatch '\\node_modules\\' } | ForEach-Object {
  $dir = $_.Directory.FullName
  [regex]::Matches([IO.File]::ReadAllText($_.FullName), '\]\(([^)]+)\)') | ForEach-Object {
    $l = ($_.Groups[1].Value -split '#')[0]
    if ($l -and $l -notmatch '^(https?:|mailto:|#|[a-z]+://)') {
      if (-not (Test-Path (Join-Path $dir ($l -replace '/','\')))) { Write-Output "BROKEN in $($dir): $l" }
    }
  }
}
```

## 8. Markdown & encoding

- UTF-8, no BOM. Unix (LF) line endings preferred.
- One H1 (`#`) per file (the title). Use `##`/`###` for sections.
- Fence code blocks with a language hint where it helps (` ```bash `, ` ```json `, ` ```hcl `).

---

*Keeping to these standards is what makes the difference between "a pile of notes" and a curriculum. When in doubt, copy the shape of Phase 01, 03, or 06 — they are the reference implementations.*
