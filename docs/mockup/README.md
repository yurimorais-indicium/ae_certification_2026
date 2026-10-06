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

**Only two hue families carry data: blue (212°) and amber (34°).**

| Meaning | Colour | H / S / L | Contrast | Where it may appear |
|---|---|---|---|---|
| Gross sales / revenue | `#4183CF` blue | 212 / .59 / .53 | 4.42 | any chart measuring money |
| Orders / units | `#C08437` amber | 034 / .56 / .48 | 5.42 | any chart measuring counts |
| Online (Individual) share | `#7FA3CC` blue, light | 212 / .42 / .65 | 6.59 | the revenue split by channel |
| Finding against expectation | `#D4556B` crimson | 350 / .58 / .58 | 4.37 | twice in the deck, both on page 4 |
| Context, absence, zero | `#6A7181` slate | 222 / .10 / .46 | 3.53 | zeros, data-quality marks, supporting detail |

The reseller share has **no colour of its own** — it is the base blue, because those bars *are* gross sales.
The channel split is a split of revenue, so it stays in the revenue family and the lighter tint carries the
online part. That is five data colours for five jobs, with no hue introduced for a single chart.

### How the palette was built

Three constraints, each verified numerically rather than by eye:

1. **Luminance follows importance.** Contrast against the card runs light blue 6.59 → amber 5.42 → blue 4.42 →
   crimson 4.37 → slate 3.53. An earlier draft had the headline revenue blue at 3.46 — the *dimmest* ink in the
   system, quieter than the grey label text beside it, so a chart about a $5 water bottle out-shouted one about
   $95M. The two data hues now sit within **1.23x** of each other instead of 1.86x.
2. **Separation where it counts.** Every pair that shares a chart clears **0.25** worst-case after simulating
   deuteranopia, protanopia and tritanopia — revenue/orders 0.65, the channel pair 0.43, revenue/crimson 0.56,
   amber/slate 0.46.
3. **One visual weight.** Saturation stays within .42–.59 and lightness within .48–.65 for the data colours.
   The combined spread scores **0.46 against 0.98** for an unconstrained palette; that spread is what makes a
   palette look assembled rather than designed.

Teal and violet were both tried for the channel pair and both rejected: teal collided with the revenue blue
(0.09), and violet sat 70° from either data hue, reading as a third family imported for one chart.

### The rules that keep it honest

**A mark takes the colour of what it measures,** never of what it happens to be about. The ten largest customers
are all resellers, but that chart measures gross sales, so its bars are blue and the finding lives in the title.

**One deliberate override, used once.** When a mark *is* the contradicted expectation — not merely about it —
crimson overrides the measure colour. That happens on exactly one chart element in the deck: the
`Bike order · ON PROMOTION` bar on page 4. It measures money, so by the rule above it would be blue; it is
crimson because the entire chart exists to show that this bar sits *below* the blue baseline beside it, and
burying that in the title would waste the one comparison the page is built on. Crimson appears twice in five
pages — that bar and the `−5.4%` value it explains — and nowhere else. If it ever appears a third time, the
override has stopped being an override.

**An absence is not an alarm.** The three marketing channels with no orders, and the 4,647 online orders with no
reason recorded, are all slate — they are not reasons and are not ranked as if they were. Crimson appears
exactly twice in five pages, both for the one result that genuinely contradicts expectation: promotions
underperforming comparable orders.

**Caveats are amber, findings are crimson.** Data-quality banners and the two time-series boundary markers use
the amber caveat treatment, so the alert colour is never spent on a footnote.

### Beyond colour

**Every chart title states the finding**, not the field names — "Resellers generate 73% of gross sales from 12%
of orders" rather than "Gross sales by channel". Rubric traceability lives in a small `QUESTION x` tag in the
card corner, so the title's first words are never spent on exam bookkeeping.

**The encoding has to survive the claim it carries.** Where a chart could mislead, the form changed rather than
the caption: question b is a dot plot on a clipped, labelled axis because its six values span under 9% and bars
would show six identical lengths; the product-line comparison shows complete lines because a top-N list of
variants made a 1.6x gap look like 4.6x; the category chart carries orders as a second encoding because its
headline makes a claim about order counts that a revenue axis cannot support.

**Data-quality caveats are rendered on the page**, not hidden in documentation: the May 2011 single trading
day, the June 2014 channel truncation, the online-only scope of sales reasons and card types, and which
groupings of the explorer table are non-additive.

**The deck ends in actions.** Page 5 closes with four one-line recommendations, each naming the figure that
justifies it and the page that proves it — findings alone are not a deliverable for a commercial audience.
