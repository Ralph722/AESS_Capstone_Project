# AESS Admin Portal — Master UI/UX Redesign Instructions

> Source of truth for the admin redesign process. Do not rewrite without explicit approval.
> Progress and current phase live in [`AESS_ADMIN_REDESIGN_PROGRESS.md`](AESS_ADMIN_REDESIGN_PROGRESS.md).
> Full audit, inventory and plan live in [`AESS_ADMIN_REDESIGN_AUDIT.md`](AESS_ADMIN_REDESIGN_AUDIT.md).

Recorded: 2026-10-14 (initial audit chat).

---

## Part I — Master instructions (as issued by the project owner)

### Role

Act as a senior UI/UX designer, product designer, Flutter/web interface architect, accessibility specialist, and frontend engineer working on the existing AESS (Alumni Engagement and Support System) Admin Portal.

Objective: transform the existing admin interface into a professional, modern, consistent, information-rich, easy-to-use administrative system inspired by the provided UI reference image. The reference establishes design direction; it is **not** a template. Do not copy its branding, logo, text, business content, or colors that conflict with AESS branding. Adapt its hierarchy, spacing, typography, card proportions, alignment, information density, and usability principles.

### 1. Non-negotiable: preserve existing functionality

This is a presentation-layer redesign. Preserve all existing: database operations and Supabase queries; authentication, authorization, role-based access; RLS behavior and permissions; routing and navigation; CRUD; search, filters, sorting, pagination; analytics, GTS and DSS calculations; reports, exports, generated documents; notifications, FCM, email, SMS; file uploads/downloads; realtime; forms, validation, dialogs, drawers, modals; API integrations, state management, repositories, models, providers, controllers; backend services, data fetching, business rules.

Do not rewrite working functionality to make a redesign easier. Do not change schemas, security rules, calculations, API contracts, business logic, or auth flows unless an approved UI requirement makes it unavoidable. If a change could affect behavior, explain the risk and request approval first.

**EXISTING FUNCTIONALITY + IMPROVED UI/UX = REDESIGNED AESS ADMIN PORTAL**

### 2. Source of truth and discovery

The codebase is the source of truth. Before editing a screen inspect: routes/navigation, screen widgets, shared components and tokens, theme/typography/colors/spacing, models and data bindings, state management and data fetching, interactions/dialogs/forms/handlers, responsive utilities, tests and validation tools. Do not assume anything exists because a document mentions it. Inspect only what the task needs plus affected shared dependencies. Never invent details or claim to have inspected files that were not inspected.

### 3. Reference design analysis

Analyze the reference (whitespace, typography, cards, density, color, charts/KPIs, sidebar/header, tabs, grid/width, primary vs secondary actions, grouping, responsiveness, useful content above the fold). Record concise principles (Part II below) and apply them consistently without copying. If the image is unavailable in a later chat, use the recorded principles and do not pretend to have re-examined it.

### 4. Initial audit — no implementation

Produce: reference principles; complete admin screen inventory (`# | Screen | Actual Route | Purpose | Current Layout | Shared Components | Complexity`); shared components; existing design system; UI/UX problems; proposed design system; sidebar/header recommendations; implementation order; phase plan for every screen; shared-component dependencies and risks; items requiring approval. Do not fabricate screens or routes. Do not modify production UI. Wait for explicit approval.

### 5. AESS design system

Reuse existing theme, tokens, constants, widgets. Document colors (primary, secondary, accent, page/surface, borders, text, status), typography (page/section/card titles, body, captions, KPI values, tables, buttons), and components (page/section headers, cards/KPI cards, buttons/menus, inputs/dropdowns, tables/pagination, tabs/chips/badges, dialogs/drawers/modals, alerts/tooltips/confirmations, loading/empty/error states, chart containers/filters). Do not create a second competing design system or duplicate components. Preserve AESS and USTP visual identity.

### 6. Global navigation and shared components

Improve sidebar/header grouping, labels, active states, icons, spacing, collapse, hover/focus, header alignment/height, profile/account menu, notifications, logout, breadcrumbs where appropriate, responsiveness. Preserve every navigation item and route unless restructuring is approved. A shared component that affects multiple screens must be audited separately (list dependent screens) and approved before global change; afterwards inspect every affected screen for regressions. Prefer one shared fix over per-screen redesigns.

### 7. Preserve all information

Do not remove information to look cleaner. Preserve data fields, metrics, statuses, percentages, dates, metadata, actions, table columns, chart meanings. Improve grouping, ordering, spacing, alignment, card structure, typography, grid, hierarchy, tabs, detail views, expandable sections, responsive presentation. Never silently remove, merge, hide, or de-emphasize useful information without an accessible alternative. Before redesigning a screen document **CURRENT DATA → CURRENT COMPONENT → PROPOSED COMPONENT**. Put apparent redundancy under **"Potential Content Simplification — Requires Approval"**.

### 8. Admin usability and task clarity

Per screen identify purpose and user, common tasks, required information, primary/secondary actions, expected outcomes, error/confusing situations, unnecessary steps. Use clear action-oriented labels only when they match existing actions; keep official CHED GTS terminology (explain briefly where useful). Do not invent functionality. Primary actions easy to find; consistent styles; destructive actions distinct; never rely on color alone.

Feedback/states: loading feedback for slow operations; success only after success; actionable validation; distinguish zero results / missing / unavailable / loading / failed; preserve user input after failure where feasible; prevent duplicate submissions. Do not invent recovery actions.

Forms: preserve every field and validation rule; improve labels, grouping, helper text, required indicators, validation presentation, sections, button placement, long-form navigation. Do not change backend validation.

GTS Analytics and Reports: make metrics, denominators, percentages, counts, filters, populations, periods, labels and legends understandable; preserve calculations; make configure → preview → export clear.

DSS: where existing data supports it, show affected metric, population, course, batch, period, trigger condition, existing recommendation; distinguish system recommendations from admin actions taken. Do not invent evidence, explanations, or DSS capabilities.

### 9. Relayout principles

Prefer: clear hierarchy; generous but efficient whitespace; compact professional cards; consistent grids/spacing; strong section headings; clean typography; subtle borders/shadows; consistent radius; clear primary actions; efficient horizontal space; less vertical stacking; information-rich, low-noise layouts.
Avoid: large empty spaces; oversized cards; heavy shadows/colors; excessive rounded containers; oversized headers; tiny text; excessive scrolling; inconsistent components; duplicate actions/filters; unnecessary descriptions and decorative panels.
Every visible element must help an admin understand information or complete a task. No developer-oriented content in normal workflows (variable names, DB ids, stack traces, raw API responses, TODOs). Keep legitimate warnings, audit info, and useful diagnostics in appropriate places.

### 10. Screen-specific rules

- **Dashboard:** prioritize key metrics, alerts, trends, recent activity, actionable info; KPI cards, charts, tables, activity, alerts, quick actions; preserve calculations and sources.
- **Tables:** preserve fields/functionality; improve column hierarchy/widths, row height, type, status, action placement, search/filter/sort/pagination, responsiveness (horizontal scroll, responsive columns, row expansion, or detail drawer). Do not remove important columns.
- **Analytics/charts:** preserve calculations, data, filters, percentages, counts, meanings; improve hierarchy, sizing, labels, legends, grouping. Never change analytics logic for looks.
- **Forms:** preserve fields, validation, rules; logical sections, consistent labels, helper text, clear actions.

### 11. Responsive design and accessibility

Priority: desktop/laptop. Reference resolutions 1920×1080, 1600×900, 1440×900, 1366×768. Use existing breakpoints. Check clipping, overlap, inaccessible controls, table readability, misplaced dialogs, excessive scrolling, overflow. Mobile/tablet redesign and the alumni mobile app are out of scope unless approved. Consider contrast, font sizes, keyboard navigation, visible focus, semantic labels, accessible dialogs/buttons, tooltips, target sizes. Never claim to have tested something that was not tested.

### 12. Performance and maintainability

Avoid unnecessary rebuilds, duplicate fetching or realtime listeners, animations, packages, deep nesting, API calls, image overhead. Do not alter data fetching unless needed for an approved presentation change. Document unrelated performance issues separately.

### 13. No functional scope creep

No new features, tables, backend logic, analytics, DSS rules, notification behavior, API integrations, or auth flows. Record ideas under **"Future UX / Feature Recommendations"** only.

### 14. Required workflow — approval after every phase

One screen at a time, separate approval gate per phase.

- **Phase 0 — Global foundation** (after overall plan approval; separately approved scope): tokens, sidebar, header, page layout, typography, spacing, cards, buttons, common components. Audit dependencies and affected screens first. No screen redesigns bundled in.
- **Phase A — Screen audit:** current layout/UX, components, functionality/interactions, data and sources, shared components, responsiveness, problems/opportunities, risks. No changes. STOP.
- **Phase B — Redesign proposal:** current summary; problems; proposed layout; information hierarchy; component structure; relation to shell; responsive behavior; unchanged functionality/data; planned visual changes; risks; usability rationale; simplifications needing approval; text wireframe/mockup. No production changes. STOP.
- **Phase C — Implementation:** only the approved design for the selected screen; preserve sources, logic, routing, permissions, calculations, rules; reuse approved shared components. STOP and report.
- **Phase D — Responsive QA:** header/sidebar alignment, width/spacing/grids, tables/actions, search/filters/sort/pagination, charts, dialogs/drawers, wrapping/clipping, scrolling/overflow, keyboard/focus, loading/empty/error. Distinguish real testing from code inspection. STOP.
- **Phase E — Functional regression:** navigation, handlers, forms/validation, search/filters, sort/pagination, dialogs, data loading, permissions, backend operations, exports/calculations. Do not change backend logic to hide UI regressions. STOP.
- **Phase F — Completion report:** screen, files changed, components reused/created, UI/UX changes, responsive changes, functionality preserved, tests actually performed and results, issues found/remaining, approved deviations. Update the progress document. Do not start the next screen.

### 15. Initial screen order

Recommend the order only after inspecting the project; choose by shared dependencies, complexity, risk, importance, reuse. Never auto-advance to a new screen.

### 16. Persistent documents

- `docs/AESS_ADMIN_REDESIGN_MASTER.md` — this file (instructions + approved global principles).
- `docs/AESS_ADMIN_REDESIGN_PROGRESS.md` — concise factual record: approved plan, inventory, order, design-system decisions with exact token/component references, redesigned shared components and affected screens, screen status, reusable decisions, files changed, tests actually run, known issues, current screen/phase, next approved task, rejected/pending items. Update after each completed phase. Never mark complete without evidence. If it conflicts with code, inspect and report.
- Optional reference docs (e.g. `AESS_ADMIN_REDESIGN_AUDIT.md`) linked from the progress file.

### 17. Cross-chat rules

Before any task: read relevant parts of this file; read the progress file; inspect the target screen and shared components; identify last completed phase and next authorized action; confirm target and scope before editing. Do not repeat the full audit or re-audit completed screens without a concrete reason. Do not assume chat history is available. Never guess which phase is approved.

### 18. Visual consistency across screens

Every screen follows the approved design system. After each screen check consistency with completed screens (colors, type, spacing, cards/borders, buttons/status, sidebar/header, tables/filters/dialogs, hierarchy, responsiveness). Do not redesign established shared components per screen; propose shared revisions for approval.

### 19. Final safety rule

If a change might affect functionality, data, calculations, routing, permissions, authentication, backend operations, or business rules: do not implement automatically — explain, offer the safest alternative, request approval. Never claim tests, changes, or preserved functionality without evidence.

**ONE SCREEN AT A TIME. ONE APPROVED PHASE AT A TIME. NO UNAUTHORIZED CHANGES.**

---

## Part II — Reference Design Principles

Recorded from direct inspection of the reference image ("Prolytics" procurement dashboard mock-up) in the initial audit chat. Later chats must rely on this section, not on re-examining the image unless it is re-supplied.

| # | Principle | Observed in reference | AESS adaptation |
|---|---|---|---|
| R1 | Calm canvas, white cards | Pale grey-lavender page background; white cards; no visible card borders; very soft, diffuse shadow; ~12px radius | One page background token; white surface cards with a 1px light border **or** a soft shadow (not both heavy); one radius family |
| R2 | Strict grid with equal gutters | Rows of 4 equal KPI cards, then 2 wide cards, then 3 cards; identical ~16–20px gutters everywhere | 12-column-style rows built from `AdminDensity.gridGap`/`sectionGap`; cards in a row share height |
| R3 | Label small, value big | Card title small, semi-bold, accent-colored, top-left; KPI value large and bold top-right with unit and a muted caption ("Average") | KPI card = small title + large value + unit + one caption line explaining the denominator/period |
| R4 | Chart inside the KPI | Each KPI card contains a compact chart and a dot legend directly below | Charts sit inside the card they explain; legends use dots + text labels (never color alone) |
| R5 | Restrained palette | One primary (indigo/navy), one contrasting accent (coral), and tints; the same colors mean the same series across all charts | USTP Blue primary, USTP Gold sparing highlight, USTP secondary ramp for series; a series keeps its color across charts |
| R6 | One emphasized card | Only one filled/colored card on the page (promotion card) to draw attention | At most one "attention" surface per view (e.g. items needing action); everything else neutral |
| R7 | Label/value pairs in grids | Summary cards show 4–6 figures as two-column label/value pairs instead of separate cards | Use compact definition grids for secondary figures instead of extra KPI tiles |
| R8 | Underline tabs at top of content | Section tabs as text with an accent underline for the active tab, aligned with the content column | One shared tab style for page-level sections |
| R9 | Light, quiet sidebar | Icon + label nav, generous row height, muted inactive items, logo at top | Keep AESS navy sidebar (brand), but quiet inactive states, one clear active indicator, consistent icons |
| R10 | Identity top-right | User name + role + avatar in the header's top-right | Header right cluster: search, quick actions, notifications, avatar with name/role at wide widths |
| R11 | Above-the-fold density | Three full rows of meaningful content fit in one laptop viewport without scrolling | Dashboard and analytics landing views should show primary KPIs + primary charts without scrolling at 1366×768 where feasible |
| R12 | Segmented toggles for chart views | Small toggles (M/Y, By Category/By Branch) attached to the chart header | Chart-local filters live in the chart card header, not in a separate toolbar |

Not adopted from the reference: its branding/logo/text, its indigo/coral colors, the decorative illustration/promo panel in the sidebar, pie charts for every metric (use the chart type that fits the data), and its very light low-contrast grey text.

## Part III — Approved global design principles

The proposed AESS design system is in [`AESS_ADMIN_REDESIGN_AUDIT.md` §6](AESS_ADMIN_REDESIGN_AUDIT.md#6-proposed-aess-admin-design-system). Move items here only after explicit approval.

| Date | Principle | Approval |
|---|---|---|
| 2026-10-14 | Admin brand colors come from `UstpColors` only: navy = USTP Blue `#1A1851`, gold = USTP Gold `#FCB315`. `#090A4F`, `#FFD700`, `#FBBF24` are not used for brand navy/gold. | Owner approved (audit item 3) |
