# Arabic fonts for app and PDF reports

These fonts are used for Arabic text in the app and in generated PDF reports (patient report, finance summary, reports screen).

## Why Arabic sometimes appears as #### or squares in PDFs

- **On web:** The PDF library’s TTF parser can throw on web, so we **do not embed** a custom font there. The default PDF font has no Arabic glyphs, so Arabic shows as `####` or replacement squares. This only affects reports generated in the **browser**.
- **On Android / iOS:** We embed an Arabic font; the first one that loads successfully from the list below is used, so Arabic should render correctly in reports.

## Fonts used for Arabic in reports (tried in order)

1. **Amiri** — `Amiri-Regular.ttf` (this folder). OFL, good for body text.
2. **Kacst Farsi** — `Fonts/KacstFarsi.ttf`. Arabic/Farsi, compact.
3. **Traditional Naskh** — `Fonts/DTNASKH2.TTF`. Classic Arabic style.
4. **Candara Arabic** — `Fonts/Candarab.ttf`. Clear, modern.
5. **Arial Unicode** — `Fonts/ARIALUNI.TTF`. Very large; full Unicode fallback.

All of the above are TTF and compatible with the report PDFs. The app uses `ArabicPdfReshaper` so letters connect correctly.

## Noto Sans Arabic

- **File:** `NotoSansArabic-Regular.ttf`
- **Use:** Fallback in finance summary PDF when Amiri is unavailable.
- **Download:** [Google Fonts – Noto Sans Arabic](https://fonts.google.com/noto/specimen/Noto+Sans+Arabic).
