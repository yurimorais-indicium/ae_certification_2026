# Dashboard mockup

Five SVG pages describing the Databricks AI/BI dashboard before it is built. Every figure shown is a
**real value queried from the dbt marts**, not placeholder data, so the mockup and the final dashboard
can be compared directly.

| File | Page | Business questions |
|---|---|---|
| `dashboard_mockup_1_overview.svg` | Overview | e |
| `dashboard_mockup_2_products.svg` | Products | b, f |
| `dashboard_mockup_3_customers.svg` | Customers & Geography | c, d |
| `dashboard_mockup_4_reasons.svg` | Sales Reasons & Promotions | — |
| `dashboard_mockup_5_explorer.svg` | Sales Explorer | a |

## Importing into Figma

1. Open a Figma file and drag all five `.svg` files onto the canvas. Figma converts each into an
   editable frame with real layers (every rectangle, label and bar is a separate object).
2. Arrange the five frames side by side.
3. Export with **File → Export frames to… → JPG** (or select the frames and use the Export panel).
4. Save the JPEG into the `deliverables/` folder for submission.

## Design rules

**Colour carries meaning and never changes between charts:**

| Meaning | Colour |
|---|---|
| Gross sales / revenue | `#0072B2` blue |
| Orders / units | `#E69F00` orange |
| Store (reseller) | `#009E73` green |
| Individual (online) | `#B577B5` orchid |
| Alert, zero, negative | `#D55E00` red |

Based on the Okabe–Ito colour-blind-safe set. The one deviation is the online-channel colour: Okabe–Ito's
pink `#CC79A7` was replaced with a muted orchid `#B577B5`, which reads less decorative *and* measures better
— simulating deuteranopia, protanopia and tritanopia, its worst-case separation from the other four colours
rises from 0.235 to 0.320.

Each colour was also checked against the two measure colours so that a category colour is never mistaken for
a measure: the channel pair keeps a minimum distance of 0.32 from both blue and orange under every simulation.

**Every chart title states the finding**, not the field names — "Resellers generate 73% of gross sales
from 12% of orders" rather than "Gross sales by channel".

**Data-quality caveats are rendered on the page**, not hidden in documentation: the May 2011 stub month,
the June 2014 channel truncation, the online-only scope of sales reasons, and the non-additive sales
reason column.
