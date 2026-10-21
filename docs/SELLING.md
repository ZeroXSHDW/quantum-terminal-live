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

## 1. Buy the domain

1. Register a domain at any registrar (Cloudflare, OVH, Gandi, Namecheap, Porkbun…),
   e.g. `quantum-terminal.eu`.
2. Keep it at the registrar's DNS for now; you will point it at the host in step 4.

## 2. Prepare the download (GitHub Release)

The paid deliverable is the **pre-built app + the 8K loop**.

1. Locally: `make dmg` to produce `build/Quantum-Terminal-Live-<version>.dmg`.
2. On GitHub, create a **Release** and attach:
   - `Quantum-Terminal-Live-<version>.dmg` (or a zip of the `.app`)
   - `Assets/Quantum-Terminal-Live-30s.mov`
3. Note the download URL (it looks like
   `https://github.com/ZeroXSHDW/quantum-terminal-live/releases/download/v3.1.0/…`).

## 3. Create the $5 product in Stripe

1. Sign up at [stripe.com](https://stripe.com) (requires identity verification —
   name, address, bank/payout details — for payouts; this is Stripe's KYC, not
   something this repo can automate).
2. Go to **Products → Add product**:
   - Name: `Quantum Terminal Live — 8K wallpaper + screensaver`
   - Price: **$5.00** (one-time)
3. Go to **Payment Links → Create payment link**, select that product, and set:
   - **After payment → Redirect** → `https://quantum-terminal.eu/success.html`
   - (Optional) require a name/email so you can re-deliver later.
4. Copy the generated link (`https://buy.stripe.com/…`).

## 4. Wire the link into the site

In `docs/index.html`, replace both occurrences of:

```
https://buy.stripe.com/REPLACE_ME
```

with your real Payment Link. In `docs/success.html`, replace the release URL
with your GitHub Release download URL.

## 5. Publish the site

**Option A — GitHub Pages (free):**

1. Push to `master`.
2. Settings → Pages → **Source: Deploy from a branch** → `/docs` folder.
3. Add your custom domain `quantum-terminal.eu`; GitHub writes a `CNAME`.
4. At your DNS registrar, add the `CNAME` record GitHub tells you to
   (and the A records for the apex, or use `www` + redirect).

**Option B — Netlify / Vercel / Cloudflare Pages:**

1. Connect the repo, set the **publish directory** to `docs`.
2. Add the custom domain `quantum-terminal.eu` and follow the DNS instructions.

## 6. Test the whole flow

1. Open `https://quantum-terminal.eu` → the live preview should animate.
2. Click **Buy now — $5** → Stripe checkout → pay with a test card
   (`4242 4242 4242 4242`) in Stripe test mode.
3. Confirm the redirect lands on `/success.html` with a working download.

## Notes

- **Refunds & support** are handled in the Stripe dashboard (or by email).
- **EU VAT** — Stripe can collect and remit VAT automatically for digital goods;
  enable it in the Stripe tax settings.
- The product stays **MIT-licensed**; buyers are paying for the convenience of a
  pre-built package, not for the code.
- Keep `docs/` assets light — the hero GIF is ~4 MB; don't commit the 80 MB `.mov`
  into `docs/`, host it as a Release asset instead.
