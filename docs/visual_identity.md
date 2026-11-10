# Visual identity — Adventure Works commercial dashboard

Reference for building the Power BI dashboard from scratch. Everything here was decided and validated during the project; the earlier mockups, prototypes and theme files were removed.

## Context

- **Company:** Adventure Works, a bicycle manufacturer that sells through two channels: resellers (stores) and online (individual customers).
- **Audience:** the Commercial Director, a skeptical reader who often opens the report **on a phone**. Every page must work in Power BI's phone layout.
- **Tool:** Power BI (`.pbix` with all DAX measures documented inside the file). The data comes from the dbt marts in `fea_academy.adventure_works_marts` through the Databricks connector.
- **Language:** all report text in English.

## Indicium rules (they override any brand manual)

1. **KPIs at the top** of every page, right below the page title.
2. **No pie or donut charts**, including ring gauges for progress.
3. **One question per page.** The page title is the question; a subtitle answers it.
4. **One theme for everything.** A single theme file, light only, applied to every page.

If a brand manual conflicts with these rules, do not decide alone: show both versions side by side and ask.

**Open conflict:** the Indicium manual's reference dashboard shows progress as a ring gauge, which rule 2 forbids. This affects share KPIs such as reseller share of gross sales (73.4%), top 10% of customers (81.7%) and online orders on promotion (12.7%). The options are a ring gauge (manual) or a horizontal bar with the value above it (rule). No decision has been made yet.

## Colour

### Series colours (fixed meaning, the same on every page)

| Role | Hex | Use |
|---|---|---|
| Revenue | `#4183CF` | Gross sales, any money measure |
| Counts | `#C08437` | Orders, units |
| Reseller channel | `#3A689E` | Store / reseller series |
| Online channel | `#4597F4` | Individual / online series |
| Promotion highlight | `#D4556B` | Promotion orders only; use sparingly |
| Absence | `#6A7181` | "No reason recorded" and other missing values |

- Validated with the dataviz palette validator on a white surface. The five coloured slots pass every check: lightness band, chroma, colour-blind separation (worst pair 16.5) and contrast of at least 3:1.
- The absence grey is grey on purpose, so it fails the chroma check. **Never place it next to the promotion crimson**: the two collapse for colour-blind readers (separation 3.4).
- Keep the channel pair (`#3A689E` reseller, `#4597F4` online) away from the revenue blue in the same chart.
- Never use a dual axis. To compare measures on different scales, use an index (for example, 2012 monthly average = 100) on one axis.

### Status colours (meaning, never a data series)

| Status | Text | Tint (chip background) | Sign |
|---|---|---|---|
| Positive | `#1E7A45` | `#E6F4EC` | ▲ |
| Negative | `#B42318` | `#FCE9E7` | ▼ |
| Alert | `#9A6200` | `#FDF2DC` | ! |

- Every text colour clears 4.5:1 on white, on the page background and on its own tint.
- Status colours appear **only as text chips with a sign and a label**, never as chart marks. For colour-blind readers the three collapse into each other (separation 3.9–5.6), so the sign and the label carry the meaning.
- Use alert for changes that need context rather than alarm. Example: average order value fell 67.6% because of a shift to small online orders, not because value was lost.

### Neutrals

| Role | Hex |
|---|---|
| Primary ink | `#1C1D2F` |
| Secondary ink | `#4A4D63` |
| Muted (axes, captions) | `#6B6F86` |
| Card | `#FFFFFF` |
| Page background | `#F4F5F8` |
| Card border | `#E3E5EC` |
| Gridline | `#E8EAF0` |
| Baseline / null | `#C9CCD6` |
| Diverging midpoint | `#EEF0F4` |
| Highlight band (e.g. January–April window) | `#EEF3FA` |

## Typography

- **Segoe UI** for all text and numbers. KPI values use **Segoe UI Semibold**.
- **Georgia** (serif, from Power BI's font list) for page titles and visual titles only.
- **Never use Georgia for numbers.** Its digits have uneven heights, which looks wrong in KPIs.
- Android has no Georgia, so Power BI mobile falls back to another serif there.

| Element | Font | Size (pt) |
|---|---|---|
| Page title | Georgia | 20–26 |
| Visual title (states the finding) | Georgia | 13 |
| KPI value | Segoe UI Semibold | 28 |
| KPI label (uppercase, tracked) | Segoe UI Semibold | 10–11 |
| Axis labels, data labels, legend | Segoe UI | 10 |

## Layout

- **Cards:** white, 12 px corners, 1 px border `#E3E5EC`, **no shadow**, 16 px padding. The page background `#F4F5F8` separates cards without needing a shadow.
- **8 px grid:** every position, size and gap is a multiple of 8.
  - Canvas 1280 × 720 (16:9), 32 px margins, 24 px gaps.
  - A tested desktop layout is a header of 72, a KPI row of 104, then charts in two columns of 792 and 400.
  - Power BI cannot set the grid from the theme; set positions in the Format pane.
- **Page structure:**
  1. Title (the question) and a one-line answer.
  2. A short scope line, e.g. "Cards: January–April 2014 vs January–April 2013".
  3. Three slicers at the top right.
  4. The KPI row.
  5. The charts.
- **Phone layout:**
  1. Title and answer.
  2. One collapsed filter button.
  3. The main KPI full width, then the other KPIs in a 2 × 2 grid.
  4. Charts stacked, the chart that answers the question first.
- **Chart titles state the finding**, for example "January–April: online +211%, resellers +41%", not "Gross sales by channel".

## Chart marks

- Lines 2 px, no markers. Only the key point (for example, the peak) gets a dot and a label.
- Bars have 4 px rounded tops and a 2 px gap between adjacent bars.
- Data labels are selective. Bars with few categories can carry labels; lines get end labels or a single highlighted point.
- A legend appears whenever there are two or more series. One series needs no legend, because the title names it.
- Gridlines are horizontal hairlines only.

## Power BI theme mapping

How these values map to the report-theme JSON:

- `dataColors`: `#4183CF`, `#C08437`, `#3A689E`, `#4597F4`, `#D4556B`, `#6A7181`, in that order.
- `foreground` `#1C1D2F`, `foregroundNeutralSecondary` `#4A4D63`, `foregroundNeutralTertiary` `#6B6F86`.
- `background` `#FFFFFF`, `backgroundLight` `#F4F5F8`, `backgroundNeutral` `#E3E5EC`.
- `good` `#1E7A45`, `bad` `#B42318`, `neutral` `#9A6200`. Power BI has no "alert" slot, so `neutral` carries the alert colour.
- `minimum` `#B42318`, `center` `#EEF0F4`, `maximum` `#3A689E`.
- `textClasses`: `title` and `largeTitle` in Georgia; `callout` and `header` in Segoe UI Semibold; `label` in Segoe UI.
- `visualStyles` for all visuals (`"*"`):
  - background white;
  - border on, `#E3E5EC`, radius 12;
  - `dropShadow` off;
  - padding 16;
  - title in Georgia 13;
  - value-axis gridlines `#E8EAF0`, axis titles off;
  - legend on top.
- Page `background` and `outspace` `#F4F5F8`. Text boxes have no background and no border.

## Indicium brand manual: differences we chose

The Indicium design system ("Indicium AI Design System") was consulted. These choices differ from it on purpose:

| Topic | Indicium manual | This dashboard |
|---|---|---|
| Fonts | Inter and Roboto Mono | Segoe UI and Georgia, which Power BI offers natively |
| Cards | Light shadow | No shadow |
| Data colours | Vibrant Blue `#3A58EE` and Atlantic Blue `#699BFB` | The validated project palette above |

What the manual and this dashboard share: 12 px card corners, an 8 px grid, a hairline border, a white or off-white surface, and dark navy ink.
