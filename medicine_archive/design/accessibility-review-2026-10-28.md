## Accessibility Audit: Medicine Archive v1
**Standard:** WCAG 2.1 AA (Android) | **Date:** 2026-10-28

Checked from the code and with Flutter's guideline matchers in
`test/ui/accessibility_test.dart` (tap targets ≥ 48dp, labelled tap targets,
text contrast ≥ 4.5:1) on every screen in light and dark themes. Real
TalkBack testing on a phone is still to do.

### Summary
**Issues found:** 5 | **Critical:** 0 | **Major:** 2 | **Minor:** 3. All fixed.

| # | Issue | WCAG | Severity | Fix |
|---|-------|------|----------|-----|
| 1 | "Reading the label…" was not announced to screen readers | 4.1.3 Status messages | 🟡 Major | Wrapped in a live region |
| 2 | Save was disabled with no hint why | 3.3.2 Labels or instructions | 🟡 Major | "Required" under Name and Quantity until filled |
| 3 | Avatar letter read before the name ("A, Anna") | 1.3.1 Info and relationships | 🟢 Minor | Avatar excluded from semantics |
| 4 | Menu button announced as "Show menu" | 2.4.6 Headings and labels | 🟢 Minor | Tooltip "More options" |
| 5 | Empty-state icons announced as unlabeled images | 1.1.1 Non-text content | 🟢 Minor | Marked decorative |

### Color contrast
Material 3 scheme from seed `#00696B`: all text on all screens passes
`textContrastGuideline` (≥ 4.5:1) in light and dark.

### Touch targets
All controls pass `androidTapTargetGuideline` (≥ 48×48dp).

### Text size
Lists and the form lay out without overflow at 200% text size.

### Also found
Writing these tests exposed a crash: two floating buttons shared a hero tag
while the reading state switched back, so opening the form after a slow
scan threw. Fixed by turning off the FAB hero animation.
