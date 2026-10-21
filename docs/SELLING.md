# Selling Quantum Terminal Live

A plain-English runbook for turning this repository into a **$5 paid download**
on a `.eu` domain. It uses only free/self-serve infrastructure — no backend, no
API keys in the repo, no custom server:

- **Storefront** — the static pages in [`docs/`](.) (`index.html`, `success.html`,
  `styles.css`).
- **Payments** — a [Stripe Payment Link](https://stripe.com/payment-links) (a
  hosted checkout; Stripe handles cards and Apple Pay for you).
- **Delivery** — a [GitHub Release](https://github.com/ZeroXSHDW/quantum-terminal-live/releases)
  hosting the `.app` and the 8K `.mov` as free download assets.
- **Hosting** — GitHub Pages (free) or Netlify/Vercel/Cloudflare Pages (free tiers),
  with the `.eu` domain pointed at it.

> The `.eu` TLD requires an EU-based registrant (individual or business). If you
> are not EU-based, pick any other TLD — the process below is identical.

The repo is already **public**, GitHub Pages is **enabled** (serving `docs/` at
`https://zeroxshdw.github.io/quantum-terminal-live/`), and the storefront is live
there now. What remains is DNS + Stripe (both need your accounts).

## 1. Buy the domain

1. Register `quantum-terminal.eu` (or your chosen `.eu`) at any registrar
   (Cloudflare, OVH, Gandi, Namecheap, Porkbun…).
2. Keep it at the registrar's DNS for now; you will point it at GitHub Pages in step 5.

> Prefer a different domain? Use that name in step 5 instead — nothing is hard-coded.

## 2. Prepare the download (GitHub Release) — ✅ done

The paid deliverable is the **pre-built app + the 8K loop**, already published:

- [`v3.1.1` release](https://github.com/ZeroXSHDW/quantum-terminal-live/releases/tag/v3.1.1)
  ships `Quantum-Terminal-Live-3.1.1.dmg` and `Quantum-Terminal-Live-30s.mov`.
- `docs/success.html` already points at both download URLs.

To refresh after a future build: `make dmg`, then
`gh release create v<version> build/*.dmg Assets/Quantum-Terminal-Live-30s.mov`.

## 3. Create the €5 product in Stripe — ✅ done

The product and payment link are already live:

- Product: **QUANTUM TERMINAL LIVE** — €5.00 (one-time)
- Payment Link: **https://buy.stripe.com/fZu4gA5KUdlP40deDr14403**
- Payment methods: Card, Apple Pay, Bancontact, EPS, Klarna, Link, Revolut Pay, Amazon Pay, Satispay

> The account's default currency is **EUR** (Ireland), so the product charges
> **€5.00** rather than $5. To switch to USD, change the product currency in the
> Stripe dashboard.

## 4. Wire the link into the site — ✅ done

`docs/index.html`, `docs/showcase.html`, and the README badge all point at the
live Payment Link above. The `success.html` download links point at the GitHub
Release assets.

### Remaining: post-payment redirect (1 click)

The link currently shows Stripe's default confirmation page after payment. To
hand customers the download automatically, set the redirect:

1. In Stripe → **Payment links** → click the link → **⋯ (More options) → Edit**.
2. Under **After payment**, choose **Redirect customers to your website**.
3. Paste: `https://zeroxshdw.github.io/quantum-terminal-live/success.html`
4. **Save**.

Until then, buyers get Stripe's confirmation page and a receipt email — the
`success.html` URL is still in the product description as a fallback.

## 5. Point the domain at GitHub Pages

Pages is already serving `docs/`. To attach the custom domain:

1. Create `docs/CNAME` containing a single line — your domain, e.g. `quantum-terminal.eu` — and commit/push:
   ```sh
   echo quantum-terminal.eu > docs/CNAME && git add docs/CNAME && git commit -m "enable custom domain" && git push
   ```
2. In Settings → Pages, confirm the custom domain is detected (GitHub reads it
   from `docs/CNAME` on the next deployment).
3. At your DNS registrar, create the records GitHub requests:
   - a `CNAME` record for `www` → `zeroxshdw.github.io`, **or**
   - four `A` records for the apex (`@`) pointing at GitHub's Pages IPs:
     `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`.
4. Wait for GitHub to verify and issue an HTTPS certificate (a few minutes).

(You can also use Netlify/Vercel/Cloudflare Pages instead — connect the repo,
set the publish directory to `docs`, and follow their DNS steps.)

## 6. Test the whole flow

1. Open `https://quantum-terminal.eu` → the live preview should animate.
2. Click **Buy now — $5** → Stripe checkout → pay with a test card
   (`4242 4242 4242 4242`) in Stripe test mode.
3. Confirm the redirect lands on `/success.html` with a working download.

## 7. Showcase it on zerodevllc.eu and zerodevllc.store

The showcase is a self-contained page, already hosted at:

```
https://zeroxshdw.github.io/quantum-terminal-live/showcase.html
```

Add it to any of your sites with a link **or** an embed:

**Link (works everywhere):**

```html
<a href="https://zeroxshdw.github.io/quantum-terminal-live/showcase.html"
   style="display:inline-block;padding:12px 22px;background:#00ff40;color:#01150a;
          font-weight:700;border-radius:6px;text-decoration:none">
  ▚ Quantum Terminal Live — $5
</a>
```

**Embed (iframe):**

```html
<iframe src="https://zeroxshdw.github.io/quantum-terminal-live/showcase.html"
        style="width:100%;max-width:760px;height:900px;border:0;border-radius:10px"
        loading="lazy" title="Quantum Terminal Live"></iframe>
```

- **zerodevllc.eu** — a hand-edited HTML page; paste the snippet anywhere in
  `<body>`. The card is dark/green, so it reads clearly against the blue page.
- **zerodevllc.store** — Shopify: add a **Custom HTML** section (or a custom
  page with the HTML editor) and paste the snippet. To sell it through Shopify
  as a product instead, use the ready-to-paste listing in
  [`docs/shopify-listing.md`](shopify-listing.md) — title, SKU, description,
  SEO and digital-fulfilment notes are all pre-written.

> Swap `REPLACE_ME` in `docs/showcase.html` (and `docs/index.html`) for the live
> Stripe or Shopify URL once the product exists, and the embed updates
> automatically on the next Pages deploy.

## Notes

- **Refunds & support** are handled in the Stripe dashboard (or by email).
- **EU VAT** — Stripe can collect and remit VAT automatically for digital goods;
  enable it in the Stripe tax settings.
- The product stays **MIT-licensed**; buyers are paying for the convenience of a
  pre-built package, not for the code.
- **Homebrew** — a ready-to-publish cask lives at
  [`packaging/quantum-terminal-live.rb`](../packaging/quantum-terminal-live.rb)
  (install via `brew install --cask ./packaging/quantum-terminal-live.rb`, or
  publish to a tap).
- **Notarization** — `make notarize` signs and notarizes the DMG with your Apple
  Developer ID (set `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID`). Requires
  a paid Apple Developer account.
- Keep `docs/` assets light — the hero GIF is ~4 MB; don't commit the 80 MB `.mov`
  into `docs/`, host it as a Release asset instead.
