# Web User Portal Adaptive UI/UX Implementation Plan

## 1. Executive Summary

### 1.1 Goal
Provide a modern, responsive, and desktop-optimized UI/UX for the AESS Web User Portal (`ustp-aess.web.app`) while preserving the existing, touch-optimized mobile experience for smartphones (both native mobile apps and mobile browsers).

### 1.2 Core Architectural Principle: Adaptive, Not Duplicated
- **No Code Forking:** The application will **not** be split into two separate apps. 100% of the backend services, Supabase/Firebase integrations, authentication flows, data models, and Cubit/Bloc state logic remain unified and untouched.
- **Responsive Presentation Layer:** Only the presentation (widget) layer adapts dynamically using breakpoints (`PortalBreakpoints`) and responsive layout builders (`LayoutBuilder`, `MediaQuery`).

---

## 2. Current State vs. Target State

| Dimension | Current State | Target Desktop Web State | Target Mobile State |
| :--- | :--- | :--- | :--- |
| **Shell Navigation** | Bottom Nav on mobile; basic `NavigationRail` on web. | Enhanced desktop sidebar with header, breadcrumbs, search, and user badge. | Compact bottom navigation bar with thumb-friendly tabs. |
| **Home Page** | Single-column vertical scroll with wide whitespace on monitors. | 3-Column Bento Grid: News & Feed (left/center) + Profile & Tracer Status (right). | Single-column vertical feed with swipeable cards. |
| **CHED GTS Tracer** | Long single-column card sequence requiring extensive vertical scrolling. | Two-pane split view: Sticky Step Index & Progress (left) + Question cards (right). | Step-by-step wizard with bottom navigation buttons. |
| **Messages / Chat** | Tap conversation list to navigate to a full-screen chat route. | Master-Detail 2-pane view: Thread list (left) + Active conversation (right). | Standard mobile chat navigation (list & detail screens). |
| **Job Opportunities** | Vertical list with modal bottom-sheet filters. | Left sticky filter sidebar (salary, industry, location) + 2/3-column card grid. | Full-screen filter sheet + single-column card list. |
| **Profile Page** | Single vertical column. | Side-by-side cards: Profile summary & avatar (left) + Education & Employment history (right). | Vertical accordion / tabbed view. |

---

## 3. Screen-by-Screen Transformation Blueprint

### 3.1 Global Shell & Navigation
- **Expanded Screens (`width >= 900px`)**:
  - Persistent or collapsible desktop navigation sidebar.
  - Desktop Top Bar: University logo, current route breadcrumbs, quick search, notification dropdown, and profile chip.
- **Medium Screens (`600px <= width < 900px`)**:
  - Slim icon-only `NavigationRail`.
- **Compact Screens (`width < 600px`)**:
  - Existing `BottomNavigationBar` with standard mobile app bar.

### 3.2 User Home / Dashboard
```
+---------------------------------------------------------------------------------------+
| TOP BAR: [USTP Logo] Alumni Portal          [Search...]   (🔔) (Alumni Avatar & Name) |
+------------+------------------------------------------+-------------------------------+
| SIDEBAR    | MAIN FEED & ANNOUNCEMENTS                | RIGHT DASHBOARD WIDGETS       |
| [Home]     |                                          |                               |
| [Tracer]   | +--------------------------------------+ | +---------------------------+ |
| [Profile]  | | University Announcement Banner       | | | GTS Tracer Progress       | |
| [Jobs]     | +--------------------------------------+ | | [████████░░] 75% Complete | |
| [Events]   |                                          | | [Resume Survey Button]    | |
| [Messages] | +------------------+ +-----------------+ | +---------------------------+ |
|            | | Job Spotlight 1  | | Job Spotlight 2 | | | Upcoming Events           | |
|            | +------------------+ +-----------------+ | | • Grand Alumni Homecoming | |
|            |                                          | +---------------------------+ |
|            | +--------------------------------------+ | | Quick Links               | |
|            | | Recent Alumni Forum Discussions      | | | • Request Transcript (TOR)| |
+------------+------------------------------------------+-------------------------------+
```

### 3.3 CHED GTS Tracer Survey (Two-Pane Layout)
- **Left Pane (Sticky ~320px)**:
  - Overall completion percentage progress bar.
  - Vertical step indicator with status badges (e.g. *Step 1: General Information* `[Done]`, *Step 2: Educational Background* `[In Progress]`, *Step 3: Employment Data* `[Pending]`).
  - Quick jump-to-section capability.
- **Right Pane (Flexible Content)**:
  - Multi-column form fields for wide viewports (e.g., Degree and Year Graduated rendered side-by-side in a 2-column grid instead of single stacked lines).
  - Clean card wrappers with clear distinction between official read-only data and editable entries.

### 3.4 Alumni Messages & Forum (Master-Detail Pattern)
- **Left Pane (~340px)**:
  - Search bar for contacts and conversations.
  - Active threads list with unread counter badges and last message snippet.
- **Right Pane (Expanded)**:
  - Active conversation header with recipient details and online/last-seen status.
  - Message bubble stream with date grouping.
  - Persistent desktop chat composer bar with attachment button, emoji picker, and Enter-to-send support.

### 3.5 Job Opportunities & Career Board
- **Left Sidebar (~260px)**:
  - Multi-select filters: Employment type (Full-time, Remote, Hybrid), Industry, Degree alignment, Location.
- **Right Content Grid**:
  - 2 or 3-column responsive card grid with quick preview drawer on card selection.

---

## 4. Technical Architecture & Breakpoints

### 4.1 Breakpoint System
The layout utilizes the existing `PortalBreakpoints` specifications:
- `compact` (< 600px): Mobile portrait.
- `medium` (600px – 899px): Tablets & foldables.
- `expanded` (>= 900px): Desktop laptops & monitors.
- `contentMax` (1100px – 1280px): Maximum reading container width for text-heavy content.

### 4.2 Helper Widget: `AdaptivePageScaffold`
A reusable layout wrapper will be created in `lib/shared/widgets/user/`:
```dart
class AdaptivePageScaffold extends StatelessWidget {
  final Widget mobileBody;
  final Widget? tabletBody;
  final Widget desktopBody;
  final Widget? desktopSidebar;
  final Widget? desktopHeader;
  // ...
}
```

---

## 5. Phased Implementation Roadmap

### Phase 1: Foundational Shell & Desktop Header
- Standardize `AdaptivePageScaffold` and desktop header widgets.
- Refine `NavigationRail` to support expand/collapse with active item tooltips.

### Phase 2: Home Page Bento Grid
- Refactor `home_page.dart` to split feed content and summary widgets on expanded screens.
- Implement responsive grid for announcements and quick actions.

### Phase 3: CHED GTS Tracer Survey Adaptive Layout
- Add sticky Table of Contents sidebar for `ched_gts_wizard.dart`.
- Refactor form step cards into 2-column input layouts for expanded viewports.

### Phase 4: Master-Detail Alumni Messages
- Refactor `user_messages_page.dart` into a two-pane master-detail layout on wide screens.

### Phase 5: Jobs, Events, and Profile Pages
- Implement sticky filter sidebar on Job Opportunities.
- Implement side-by-side profile overview cards.
- End-to-end responsiveness verification across Chrome, Edge, Safari, and mobile viewports.
