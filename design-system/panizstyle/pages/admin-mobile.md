# PANIZ Admin Mobile

## Product intent

An operational control panel for the PANIZ women's apparel store. Prioritize quick daily actions, clear order and stock status, and readable financial summaries. This admin experience is deliberately separate from the customer storefront visual language.

## Visual direction

- Light editorial dashboard with a warm, near-white canvas and quiet white surfaces.
- Teal is the primary action color; rose, peach, lilac, mint, and coral are restrained supporting accents.
- Use dark mode as a fully themed option with the same hierarchy and semantic colors.
- Rounded cards and controls, thin borders, minimal shadows, and generous spacing.
- Persian RTL is the default; numeric values remain easy to scan and long IDs may use LTR alignment.

## Tokens

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| Primary | `#0F766E` | `#55B9AA` | Main actions, selected navigation, links |
| Primary soft | `#D9F1EB` | `#1A3E39` | Selection, icon backgrounds |
| Canvas | `#F6F7F9` | `#111917` | App background |
| Surface | `#FFFFFF` | `#1A2422` | Cards and dialogs |
| Ink | `#222936` | `#F2F7F6` | Primary text |
| Muted | `#5F6B78` | `#B5C3C0` | Supporting text |
| Line | `#E3E8EC` | `#384642` | Dividers and outlines |
| Success | `#16803C` | `#69D3A4` | Paid, delivered, published |
| Warning | `#9A5B00` | `#FFC66E` | Pending and attention |
| Error | `#B42318` | `#FF938D` | Cancelled, destructive actions |

## Navigation and screen patterns

- Keep five persistent bottom destinations in RTL order: Home, Products, Orders, Reports, More.
- Show a moon/sun theme toggle in the top bar on login, main tabs, and secondary tool pages.
- Keep secondary tools in the right-side drawer or More: inventory, store appearance, and account security.
- Dashboard cards display values returned by the API. Do not invent sales trends or chart data that the API does not provide.
- Lists use status pills, concise supporting details, visible refresh/error states, and empty states with a clear next action.
- Product creation stays available through a floating action button on the Products tab.
- Keep important controls at least 48 dp high and make loading, error, and disabled states visually distinct.

## Interaction details

- Pull to refresh on dashboard and operational lists.
- Confirm destructive product and image actions.
- Use a reasoned inventory adjustment flow and require a tracking code when an order is marked shipped.
- Persist the administrator's light/dark preference locally.
- Use the sun icon in dark mode to switch to light, and the moon icon in light mode to switch to dark.
- Preserve existing API contracts and business rules while changing presentation.

## Implementation

The Flutter implementation lives under `apps/admin-mobile/lib/`. Theme tokens are centralized in `core/paniz_theme.dart`; shared page headers, status pills, empty states, and skeletons are in `core/ui_helpers.dart`.
