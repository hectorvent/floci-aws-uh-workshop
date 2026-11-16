# Slides

reveal.js 5.2.1 deck for "Give Your Agent a Cloud It Can Break". Everything is vendored in `vendor/`, so it works offline.

```bash
cd slides
python3 -m http.server 8000      # then open http://localhost:8000
```

| Key | Action |
|---|---|
| `S` | Speaker view with notes and timer |
| `F` | Fullscreen |
| `R` | Replay the agent log on the "Twelve attempts" slide |
| `Esc` | Slide overview |

- Content: `index.html`. Styling: `theme.css`. Behavior, QR links and the illustrative agent run: `deck.js`.
- Branding follows the floci.io design system (night indigo, indigo accent `#7A7FD6`, Sora and Space Mono), the same tokens as the floci-demo-qa deck. Fonts are vendored in `vendor/fonts/` (SIL OFL).
- `assets/`: `uh-logo.svg` (official reverse logo from uh.edu, for dark backgrounds), `floci-logo.svg`, `hector-profile.png`. The Floci mark is also inlined once in `index.html` as `<symbol id="floci-logo">`.
- QR codes are generated in the browser from `LINKS` in `deck.js`. Update `workshop` once the repo is published.
- Export to PDF: open `http://localhost:8000/?print-pdf` in Chrome and print to PDF.
