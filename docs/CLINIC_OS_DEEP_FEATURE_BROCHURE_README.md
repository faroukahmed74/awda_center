# Clinic OS — Deep Feature Brochure

Icon-level marketing pack with **full-page desktop** and **mobile** screenshots.

| Output | Path |
|--------|------|
| HTML | [`CLINIC_OS_DEEP_FEATURE_BROCHURE.html`](./CLINIC_OS_DEEP_FEATURE_BROCHURE.html) |
| PDF | [`CLINIC_OS_DEEP_FEATURE_BROCHURE.pdf`](./CLINIC_OS_DEEP_FEATURE_BROCHURE.pdf) |
| Word | [`CLINIC_OS_DEEP_FEATURE_BROCHURE.docx`](./CLINIC_OS_DEEP_FEATURE_BROCHURE.docx) |
| Shots | [`marketing_screens/desktop/`](./marketing_screens/desktop/), [`mobile/`](./marketing_screens/mobile/), [`states/`](./marketing_screens/states/) |

## What’s explained

- Global app-bar icons (Messages, Notifications, Refresh, Language, Theme)
- Appointments: status chips, Day/Month/Year, **List vs Schedule**, Services/Packages/Doctor/Performing-doctor filters, counters, search, date nav, legend, card cells, ⋮ menu
- Income & Expenses: add income/expense, type & period chips, all dropdowns, summary cards, row menus
- Finance summary: Target, 30% factor, PDF/Save, doctor table columns, NET / Rent+guard / Receptionist / **MANG** / **BASKET** / Profit, commission slices
- Mobile captures of Dashboard, Appointments, Income, Finance summary

## Regenerate

```bash
# PDF
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf=docs/CLINIC_OS_DEEP_FEATURE_BROCHURE.pdf \
  "file://$(pwd)/docs/CLINIC_OS_DEEP_FEATURE_BROCHURE.html"

# Word
cd docs && pandoc CLINIC_OS_DEEP_FEATURE_BROCHURE.html -o CLINIC_OS_DEEP_FEATURE_BROCHURE.docx --resource-path=.
```
