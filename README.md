# REKONSILIASI OBAT — Puskesmas Ngalupolo
Responsive PWA for stock reconciliation and patient medication-reconciliation indicators.

## Current status
- Static PWA frontend and GitHub Pages deployment workflow.
- Offline app shell with Service Worker; local mode stores data in this browser/device only.
- Optional Supabase shared database integration is included but **not active until configured**.
- No real patient-identifying data should be entered. The patient module records only a pseudonymous case code and aggregate indicators.
- This is a starter implementation; test calculations and access policies with a designated team before official operational use.

## GitHub Pages publishing
1. Open repository Settings → Pages.
2. Under Build and deployment, select **GitHub Actions**.
3. The workflow `.github/workflows/pages.yml` deploys on pushes to main.
4. After the first successful workflow run, open https://madeadja2026-sys.github.io/rekonsiliasi-obat/
5. If the repo URL differs, update the homepage URL in this README and test PWA install over HTTPS.

## Configure a shared database (Supabase)
1. The frontend cannot itself create a secure shared database. Create an organization-controlled Supabase project using an institutional email, set MFA, and assign at least two trusted admins.
2. Open Supabase SQL Editor and run `supabase/schema.sql` after review by the person responsible for IT/security.
3. In Authentication → Providers, keep Email enabled; disable public sign-ups. Create staff accounts manually from the Auth dashboard. Use individual accounts, never a shared password.
4. Add one row per Auth user in `public.user_profiles`, with their auth UUID and a role: admin, apoteker, petugas, or viewer. The admin row must be provisioned securely by the project owner.
5. Copy Project URL and the **anon/publishable key** into `config.js` as SUPABASE_URL and SUPABASE_ANON_KEY. Never put the service_role/secret key in a browser file.
6. Commit the updated config. Verify RLS is enabled and test each role with separate accounts before using real operational data.
7. In Supabase project settings, configure daily backups/Point-in-Time Recovery if available for the chosen plan, review retention and restore process, and periodically export a separate encrypted backup to approved institutional storage. A CSV/JSON export from local mode is not a shared-database backup.
8. Configure an institutional privacy notice, account removal/offboarding procedure, incident response, and audit review. Consider a formal data-protection review before storing any health-related data.

## Roles
- admin: manage profiles, read/write/correct/delete records.
- apoteker: read records, add records, correct records.
- petugas: read records and add records.
- viewer: read-only.
These are starter roles. Confirm exact permissions and who may approve stock adjustments internally.

## Calculation rules
For a location and item, opening balance is the sum of all earlier movements. For the selected period:
closing administrative balance = opening + receipts + transfer-in + returns - transfer-out - use - expired/damaged + approved adjustments.
Transfer-out and transfer-in are recorded at their respective locations and are **not patient consumption**.
The physical-stock field currently mirrors the administrative balance because this starter UI does not yet include a physical-count entry field. Before official reconciliation, add a verified physical count input and discrepancy approval workflow. Do not treat the current zero-difference placeholder as a completed stock opname.
Stock status thresholds (critical <=5, low <=20, surplus >1000) are demo defaults, not official thresholds; set locally approved thresholds before operational use.
Sample data is labeled DATA CONTOH. Use “Unduh cadangan JSON” for local backup; this does not back up shared Supabase data.

## Offline behavior
- PWA shell and same-origin files are cached after the first successful online visit.
- Local mode can read/write local browser storage offline.
- Shared mode requires a network connection to sign in and sync. Offline entries are not automatically queued/synced to Supabase.
- On Android Chrome: open the HTTPS app URL → menu ⋮ → Install app / Add to Home screen.
- iPhone/iPad: Safari → Share → Add to Home Screen.
