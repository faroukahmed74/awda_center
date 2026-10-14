# Clinic OS — Generic Marketing Brochure

White-label / generic sales materials (no clinic brand name) describing **all product features** across Web, Android, and iOS.

| File | Use |
|------|-----|
| [`CLINIC_PLATFORM_MARKETING_BROCHURE.html`](./CLINIC_PLATFORM_MARKETING_BROCHURE.html) | Open in any browser (offline; uses `../assets/fonts/`) |
| [`CLINIC_PLATFORM_MARKETING_BROCHURE.pdf`](./CLINIC_PLATFORM_MARKETING_BROCHURE.pdf) | Printable / email / WhatsApp |

Product name in the brochure: **Clinic OS** / **نظام إدارة العيادة** — replace with the buyer’s clinic brand when you close a deal.

## Regenerate PDF

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf=docs/CLINIC_PLATFORM_MARKETING_BROCHURE.pdf \
  "file://$(pwd)/docs/CLINIC_PLATFORM_MARKETING_BROCHURE.html"
```

Or open the HTML → **⌘/Ctrl + P → Save as PDF**.
