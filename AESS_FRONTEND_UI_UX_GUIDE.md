# AESS Frontend UI/UX Guide

Default development rules for future UI/UX tasks on the AESS project.

## Development rules

- Focus strictly on frontend UI/UX improvements.
- Inspect the existing screen and related widgets before modifying anything.
- Preserve backend integrations, Supabase queries, database operations, business logic, permissions, and existing functionality.
- Avoid unrelated refactoring and unnecessary dependencies.
- Reuse existing design tokens, shared components, and application patterns.
- Improve visual hierarchy, spacing, typography, alignment, consistency, responsiveness, and usability.
- Maintain mobile, tablet, and desktop web compatibility.
- Never replace functional components with static mockups or hardcoded sample data.
- Do not claim completion without implementing and inspecting the changes.
- Modify only the explicitly selected screen.

## Required workflow

1. **AUDIT** — Inspect the screen, dependencies, and functionality. Present proposed improvements without modifying files.
2. **IMPLEMENT** — Wait for my approval, then implement only the approved changes.
3. **REVIEW** — Inspect actual code changes, identify unintended modifications, and verify functionality preservation as far as possible.

Never proceed to another screen without my explicit approval.
