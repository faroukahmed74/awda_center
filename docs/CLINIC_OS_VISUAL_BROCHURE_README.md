# Clinic OS — Visual Marketing Brochure (Real Screens)

| File | Description |
|------|-------------|
| [`CLINIC_OS_VISUAL_BROCHURE.html`](./CLINIC_OS_VISUAL_BROCHURE.html) | Offline HTML with embedded gallery of **real screenshots** |
| [`CLINIC_OS_VISUAL_BROCHURE.pdf`](./CLINIC_OS_VISUAL_BROCHURE.pdf) | Printable PDF |
| [`CLINIC_OS_VISUAL_BROCHURE.docx`](./CLINIC_OS_VISUAL_BROCHURE.docx) | Microsoft Word |
| [`marketing_screens/`](./marketing_screens/) | Raw PNG captures from the live web app |

Generic product name: **Clinic OS** / **نظام إدارة العيادة** (white-label; no Awda branding in brochure copy).

## Regenerate PDF

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf=docs/CLINIC_OS_VISUAL_BROCHURE.pdf \
  "file://$(pwd)/docs/CLINIC_OS_VISUAL_BROCHURE.html"
```

## Note

Screenshots were captured from the production web build while logged in as admin. Some operational screens (empty todos/requirements) still illustrate the UI chrome. Patient detail / appointment dialogs / schedule grid can be added in a follow-up capture pass.
