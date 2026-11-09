---
icon: lucide/palette
---

# Design direction

antislop is applied during implementation, as requested. The owner authorized
defaults and reference research; these are agent-selected defaults for review,
not a claim of a supplied brand specification. No optional antislop skills or
persistent AGENTS.md changes are needed for this work.

Reading this as: an educational storefront for students and demo visitors,
using an editorial catalog language, ENERGY 2 / RHYTHM 2 / MOTION 1.
Admin uses ENERGY 1 / RHYTHM 1 / MOTION 1 for predictable repeated tasks.

## Visual decisions

| Choice                                                                       | Reason                                                                                                                          |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Existing platform mark with Microsserv52 wordmark                            | Preserve the actual project identity rather than inventing a new logo                                                           |
| Warm paper background, dark ink text and deep rust accent                    | Separate browsing surfaces from actions while giving the demo a recognizable catalog identity                                   |
| System sans-serif body and Georgia editorial headings                        | Keep controls familiar and readable, give landing/product headings contrast, and avoid a new font dependency or network request |
| Product cards with visible names, units and USD prices                       | The Product contract supplies those fields; the catalog remains useful without invented photography                             |
| Neutral initials/text tile where imagery is absent                           | Make missing product media honest rather than creating unsupported product claims                                               |
| Compact, stable admin sidebar and tabular data                               | Repeated catalog/account tasks need predictable locations rather than decorative dashboard charts                               |
| Generous landing introduction, denser store grid and restrained admin tables | Density follows the visitor's task rather than repeating one landing-page template                                              |
| Small corner radii and borders; elevation only for overlays                  | Distinguish interactive layers without making every surface float                                                               |
| Light/dark/system theme with explicit contrast checks                        | Support visitor preferences and verify every shipped theme                                                                      |
| Hover/focus feedback, no ornamental motion                                   | Keep attention on browsing, validation and demo order review                                                                    |
| Menu, theme and destructive-action Material icons                            | Identify the navigation drawer, color preference and delete action rather than decorate content                                 |
| Plain section labels above editorial headings                                | Give catalog/demo context without inventing promotional status badges                                                           |

## Reference research

- [MUJI storefront](https://www.muji.us/): observed its prominent search,
  catalog-first navigation and clear hierarchy. Do not reproduce branding,
  marketing popups, photography or sales claims.
- [MUI dashboard](https://mui.com/material-ui/getting-started/templates/dashboard/):
  observed sidebar, breadcrumbs and table organization. Do not copy its sample
  users, analytics counts, promotional cards or charts.
- [21st.dev commerce component search](https://21st.dev/community/components?q=ecommerce%20product%20cards%20search%20navigation):
  reviewed product-card, catalog-grid and search/navigation previews for
  composition. Implement with the approved MUI/Tailwind stack; no third-party
  component source or extra runtime dependency is copied.
- [antislop core](https://raw.githubusercontent.com/miqdadbadjuber/anti-slop/main/antislop.md):
  governs design review and verification. UI compliance is assessed on the
  running applications, not inferred from this document.

## Content and verification

Use “Browse demo catalog”, “Add to demo cart” and “Create demo order” for actions.
Make the mock-store notice visible throughout: no real payments or transactions
and no shipment. Use only real API data or explicitly labeled test fixtures.
No invented testimonials, performance statistics, revenue or inventory.

Every page needs one clear focal point, valid navigation, functional controls
and empty/loading/error states. Verify mobile overflow, minimum 44px touch
targets, keyboard/focus behavior, reduced motion, media dimensions and both
themes. Record actual build results and control-by-control browser evidence in
the delivery report. Lighthouse/field performance are “not measured” unless
actual measurements are captured.
