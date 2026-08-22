# OfficeAI — Requirements Specification

**Status:** Draft v10 (v4 revised against interactive prototype `docs/prototype.html`; v5 added the Manager role + Seen field; v6 corrected Manager's rank above Power User; v7 fixed two bugs found in Phase 1 testing; v8 documents Phase 2's Tender-EMD + Work Orders & FD build; v9 adds the App Version Gate, §5.2; v10 adds the `pending`-by-default account-status security fix, §4)
**Stack:** Flutter (Android, iOS, Web, macOS, Windows) + Firebase (Auth, Firestore, Cloud Storage, Cloud Functions)

> This revision replaces the placeholder/assumed field lists from the prior draft with the actual fields, dashboards, and business rules found in the source spreadsheet (10 sheets: `Inward Outward`, `Tender-EMD`, `Workorder Track`, `fixed deposit`, `Employe data`, `Resume`, `Inventory`, `vechicle insurance`, `epf`, `MyNotes`). Several assumptions in the prior draft turned out to be **wrong** — see §0.

---

## 0. Corrections from the prior draft

- **"Employee Inventory" is not an IT/asset inventory.** The `Inventory` sheet is just uniform/cap stock (item, size, quantity) — very sparse (3 rows), likely still an early sketch. See §9.3.
- **"Vehicle Insurance Management" is not managing the company's own vehicles.** It's a full insurance-agency sales module — customers, policies sold to them, commission earned, renewal follow-ups. This is a client-facing revenue line, not an internal fleet-admin tool. See §9.4.
- **"EPF Management" is not internal payroll/EPF for OfficeAI's own staff.** It's a separate consultancy business ("Classic Consultancy") that files EPF claims/services (withdrawal, transfer, UAN activation, etc.) on behalf of external clients, with its own case-tracking workflow and income/fee tracking. See §9.5.
- **Resume ≠ Employee.** `Employe data` (the org's own staff) and `Resume` (a candidate/manpower database for placement roles — security guard, housekeeping, electrician, driver, etc.) are two distinct entities. This suggests the organization staffs facility/security-type contracts and keeps a separate applicant pool for that. See §9.1–9.2.
- **EMD and FD are not directly linked to an inward document.** Per `MyNotes`: EMD is standalone, submitted at tender time, and returned once the Work Order is issued (rarely converted into an FD). FD is issued **against a Work Order**, not against the tender itself.

Given this, OfficeAI is better understood as: a document/tender/work-order tracking system for an organization that bids on government contracts (likely facility/security/manpower services, given the Resume categories), bundled with two unrelated service-line CRMs (vehicle insurance agency, EPF consultancy) that happen to be built on the same app.

**Recommend confirming with the stakeholder (Vishwas):** should the vehicle insurance and EPF consultancy modules really live inside "OfficeAI," or are they separate businesses that only share the app shell/login? This affects data isolation and role design (§4.1).

### 0.1 Changes from prototype review (v4)

The interactive prototype (`docs/prototype.html`) was built out to all 8 modules plus a unified home Dashboard, and in doing so made a few concrete decisions that either resolve open questions from v3 or introduce features not previously specified. These are folded into this revision — see inline notes in §3, §6.1 (new), §9.2, §11, and the updated §12. **All of the below should be explicitly confirmed with the stakeholder before being treated as final**, since the prototype made these calls for demo purposes rather than from an explicit source answer:

- Final navigation adopted all 8 areas as top-level items, but split "Deposits" across two sections instead of one combined tab (§3).
- A cross-module home Dashboard was introduced (aggregated KPIs, "Needs attention" and "Recent activity" feeds, activity-by-task-group chart) — not previously specified (§6.1).
- A single global search box was added to the top bar, spanning documents/tenders/people — in addition to (not instead of) each module's own scoped search (§3.1).
- WhatsApp integration was prototyped as deep-linking with a pre-filled message and an "Open WhatsApp" button, not a Business API integration (§11, §12 item 7 — now resolved).
- Resume/Candidate Bank dashboard groups by category (Security, Housekeeping, ...) rather than district (§9.2, §12 item 6 partially informs — grouping dimension is no longer TBD, but see note there).

---

## 1. Overview

OfficeAI is a cross-platform office automation application built with Flutter and Firebase, centralizing:
1. **Inward/Outward document register** — all correspondence in and out of the organization.
2. **Tender-EMD and Work Order tracking**, including EMD and Fixed Deposit lifecycle.
3. **Employee database** (own staff) and a separate **candidate/resume database** (manpower pool for placement roles).
4. **Uniform/apparel inventory** (early-stage, sparse spec).
5. **Vehicle Insurance agency module** — sell and track customer policies, commission, renewals.
6. **EPF Consultancy module** — client case management for EPF-related government filings.

### 1.1 Goals
- Single system of record for task-linked inward/outward correspondence and supporting documents.
- Track EMD lifecycle (deposit → refund) and Work Order → Fixed Deposit lifecycle independently.
- Fast retrieval via tagging and search; WhatsApp-based reminders/sharing as a first-class feature (repeatedly requested across sheets — Inward/Outward, EMD, Vehicle Insurance).
- Role-based access control (RBAC) with an audit trail.
- One Flutter codebase across five platforms.

### 1.2 Non-Goals (confirmed via `MyNotes`)
- No job-posting storage or resume-matching feature — explicitly ruled out ("Job Postings are not stored in the database. So, there is no need to match.").
- No e-signature/approval-workflow engine beyond the EPF module's own case-status pipeline (§9.5.3).

---

## 2. Target Platforms

| Platform | Status |
|---|:---:|
| Android | Supported |
| iOS | Supported |
| Web | Supported |
| macOS | Supported |
| Windows | Supported |

---

## 3. Application Structure / Navigation

Per `MyNotes` (item 5), the intended main screen tabs are:
- **Inward Outward**
- **Work Orders**
- **Deposits** (EMD and FD)
- **Resume**

The `Employe data`, `Inventory`, `vechicle insurance`, and `epf` sheets are not listed among these four tabs but are fully specified as their own modules elsewhere in the workbook — treat them as additional top-level sections/tabs alongside the four above pending explicit confirmation of final navigation/IA.

**Resolved by prototype (needs stakeholder sign-off):** the prototype implements all 8 areas as top-level nav items, grouped into sections — Overview (Dashboard), Documents (Inward/Outward), Task Groups (Tender-EMD, Work Orders & FD), People (Employees, Candidate Bank), Operations (Inventory), Client Services (Vehicle Insurance, EPF Consultancy), Admin (Manage Users, Audit Log — Admin-only). Note this **diverges from `MyNotes` item 5**: rather than one combined "Deposits" tab for EMD + FD, the prototype keeps EMD under Tender-EMD and folds FD into Work Orders as a second sub-tab (consistent with the confirmed §8.4 rule that FD is issued against a Work Order, not a tender). **Confirm with Vishwas** whether this split is preferred over a single unified Deposits tab.

### 3.1 Global Search

The prototype adds a single search box in the top bar ("Search documents, tenders, people…") spanning multiple modules, in addition to each module's own scoped search (§6.5, §7.7, §9.1, §9.2, §9.4, §9.5.8). Not previously specified — **confirm scope**: which record types it should query, and whether results route into the relevant module's own list/detail view.

---

## 4. User Roles & Permissions

| Capability | Admin | Manager | Power User | General User |
|---|:---:|:---:|:---:|:---:|
| View & download documents | ✓ | ✓ | ✓ | ✓ |
| Search documents | ✓ | ✓ | ✓ | ✓ |
| Upload new documents | ✓ | ✓ | ✓ | — |
| Delete documents | ✓ | ✓ | ✓ | — |
| Acknowledge "Seen" on Inward/Outward documents (§6.2/§6.3) | ✓ | ✓ | ✓ | — |
| Manage categories/tags | ✓ | ✓ | ✓ | — |
| Manage users (roles, status) | ✓ | — | — | — |
| View audit logs | ✓ | — | — | — |

**Role values (Firestore):** `admin`, `manager`, `power_user`, `general_user`

**Account status values (Firestore, added post-v8 — security hardening, not from the source):** `pending`, `active`, `disabled`. A self-registered account starts as `pending` (no read/write access to any business data, per `firestore.rules`' `activeRole()`) and only becomes usable once an Admin approves it from Manage Users. This closes a real gap: Firebase's Email/Password sign-in doesn't check that a request came from *this* app specifically — anyone holding the project's public Firebase config (which every real user's device already has, and which is fine to publish in source control per Firebase's own guidance) could otherwise self-register via the Auth REST API directly and, before this change, immediately read Inward/Outward/Tender/Work-Order data as a brand-new `general_user`. Defaulting new accounts to `pending` means self-registration alone grants nothing until a human approves it.

**Manager role (added post-v4, not in the source spreadsheet):** ranked *above* Power User, below Admin — a Manager can do everything a Power User can (create/edit/delete Inward/Outward documents) plus is explicitly called out as able to toggle the "Seen" flag (§6.2/§6.3), so other users can confirm a document has been reviewed. In practice Power User already had this ability too (Seen is just another document field, and Power User has full document-write rights) — Manager doesn't unlock a new capability so much as sit at a higher rank than Power User for future role-gated features. General User sees "Seen" read-only. Confirm this hierarchy (Manager > Power User) matches intent — an earlier build placed Manager *below* Power User with Seen-only write access; this was corrected per stakeholder direction.

### 4.1 Open question — module-level access
The spreadsheet surfaces two modules carrying **client financial/PII data with income tracking** (Vehicle Insurance commissions, EPF consultancy fees) and one with **employee PII** (Aadhaar, PAN, salary-adjacent data). Recommend a finer permission layer than the single 3-role matrix above — e.g., should a General User in the tender/document part of the app even see the EPF consultancy client list or income figures? Not specified in the source; needs a decision.

---

## 5. Authentication

- Email and password sign-in via Firebase Authentication; show/hide password toggle; loading indicator on sign-in; errors as snackbars.
- Forgot Password: Firebase reset email; success/error as snackbars.
- `authStateChanges` drives GoRouter route protection; unauthenticated users redirected to Login; authenticated users on Login redirected to Dashboard; sign-out clears session.

**Note:** `MyNotes` item 4 explicitly asks "Do you need additional userid/password for login?" and was left unanswered in the source — flag this as still open, though Firebase email/password (as specified elsewhere) is assumed authoritative unless told otherwise.

---

## 5.1 Home Dashboard (new — from prototype, not in source spreadsheet)

The prototype introduces a cross-module landing dashboard (separate from each module's own dashboard in §6.1, §7.4, §8.4, §9.1, §9.2, §9.4, §9.5.1). Not present in the source spreadsheet — **confirm as an addition** before building:

- **Aggregated KPI tiles:** Total Inward, Total Outward, Today's Inward, Today's Outward, EMD Pending Refund (₹ + count), FD Maturing in 30 days (count + ₹ total).
- **"Activity by Task Group" chart:** document/record volume by task group (Tender-EMD, Work Orders, Fixed Deposit, General Correspondence) for the current quarter.
- **"Needs attention" feed:** cross-module alert list merging EMD-refund-due, FD-maturing, and insurance-policy-expiring items with an urgency chip (days remaining).
- **"Recent activity" feed:** latest create/update events across modules (visible to all roles) — distinct from the Admin-only Audit Log (§10); **confirm** whether a non-admin-facing activity feed is desired given it surfaces record references (e.g. inward/outward numbers) to General Users, or whether it should also be role-gated.

---

## 5.2 App Version Gate (new — requested during Phase 2 implementation, not in source spreadsheet or prototype)

Since the app is distributed as standalone builds on some platforms (e.g. a Windows `.exe` handed directly to a customer, rather than an auto-updating app store listing), there's no built-in way to force a stale build to stop working once a newer one exists. Admins can configure an allowed app-version range; any build outside it is **hard-blocked before login** — the user sees an "Update Required" screen with the required range and a custom message, and can't reach the sign-in screen at all.

- **Config:** a single Firestore document (`app_config/version_gate`) with `minVersion`, `maxVersion` (either may be blank for "no bound in that direction"), and a custom `blockMessage`. Compared against the running build's own version (from `pubspec.yaml`'s `version:`) using standard semver precedence (`1.9.0 < 1.10.0`, build metadata after `+` ignored).
- **Enforcement point:** checked once at app startup, ahead of routing — so it applies uniformly whether the user would have landed on `/login` or a deep link into the app.
- **Access model:** the config document is readable **without signing in** (it carries no sensitive data — just two version strings and a message) so the block can trigger before authentication; only Admins can write it. If the document has never been configured, the gate defaults to **allowing everything** (fail-open) — a fail-closed default would lock out every user, including the admin who'd need to sign in to fix it.
- **Admin UI:** `/admin/app-version`, a form to set the range and message, admin-only like Manage Users/Audit Log.
- **Not built:** an in-app "download the new version" link/auto-updater — the block screen tells the user a build outside the range isn't supported but doesn't fetch or install anything. Confirm if that's needed later (would differ meaningfully per platform: web can just reload, desktop/mobile need a real distribution channel).

---

## 6. Inward / Outward Document Register

### 6.1 Dashboard
- Total inward documents
- Total outward documents
- Today's entries

### 6.2 Inward Entry Fields
1. Inward Number (auto-generated)
2. Date & Time
3. Received From
4. Sender Company/Person
5. Subject
6. Department
7. Priority (Normal / Urgent)
8. File Upload (PDF/Image)
9. Receiver Name
10. Remarks
11. **Seen** (added post-v4) — boolean acknowledgement flag, toggled only by Manager/Power User/Admin (§4), so other users can confirm a Manager has reviewed the document. Not editable by General User (read-only indicator instead).

### 6.3 Outward Entry Fields
1. Outward Number (auto-generated)
2. Sent To
3. Address / Email
4. Subject
5. Department
6. Dispatch Mode (Courier / Post / Hand Delivery / Email)
7. Tracking Number
8. Attached File
9. Sent By
10. Remarks
11. **Seen** (added post-v4) — same acknowledgement flag as §6.2 item 11.

### 6.4 Document Types (per `MyNotes`)
- **Outward:** Work Order, Letters, Request for EMD Clearance, Request for References, Request for Recommendations, etc.
- **Inward:** Work Order (the answer given is incomplete/single-item — **confirm** whether Tender documents and other inward types should also be enumerated, since the question explicitly asked about this and the answer only names one type).

### 6.5 Search & Reports
- **Search by:** Document number, Company name, Subject, Date, Department.
- **Reports:** Daily report; Monthly inward/outward report.

### 6.6 App-level convenience features (called out explicitly as "Friendly Features")
- Camera scan (capture a document directly instead of only file-upload).
- Upload from gallery.
- WhatsApp sharing.

---

## 7. Tender-EMD

### 7.1 Tender Details
1. Tender Indent Number
2. Tender Name
3. Department Name
4. Tender Category (Work / Supply / Service)
5. Tender Publish Date
6. Tender Submission Date

### 7.2 EMD Details
1. EMD Amount
2. EMD Type (DD / Online Payment)
3. UTR / URN Number

### 7.3 Department Contact Details
1. Department Name
2. Contact Person
3. Mobile Number
4. Email ID
5. Office Address

### 7.4 Dashboard
- Total EMD Deposited
- Total EMD Pending
- Total EMD Refunded

### 7.5 Reports
- Pending Refund Report
- Total EMD Deposited Report
- Total EMD Refunded Report

### 7.6 Alerts & Reminders
- EMD validity expiring in 15 days — **build-time note:** the source never defines what "EMD validity" date this is measured against. Implemented as an optional `EMD Valid Until` field on the tender record; if left blank, this alert simply doesn't fire for that tender. Needs stakeholder confirmation.
- Refund pending for more than 30 days — computed from `Refund Status = Pending` + days elapsed since Submission Date, not a stored value.

**Refund Status values (implemented):** `Pending`, `Refunded`, `Forfeited` — "Forfeited" wasn't explicitly listed in the source field list but is a standard EMD outcome and is exposed as a filter option; confirm it's wanted.

### 7.7 Search & Filters
- Tender Number, Refund Status, Department

### 7.8 WhatsApp Integration
One-click reminder template: *"Sir, kindly refund of EMD refund against Tender No. XXXXX for ₹50,000 Tender name."* — needs a defined variable set (tender no., amount, tender name at minimum) and a target recipient (department contact from §7.3).

---

## 8. Work Order Group

### 8.1 Work Order — Basic Fields
| Field | Purpose |
|---|---|
| Work Order Date | Issue date |
| Department Name | Government department |
| Contract Type | Fixed / Extension / Till Next Tender |
| Start Date | Contract starting date |
| End Date | Contract ending date |
| Extension Available | Yes/No |
| Status | Active / Expired / Extended |
| Remarks | If applicable |

**Contract type detail:**
- **Fixed Period Contract** — explicit start/end date range.
- **Till Next Tender** — open-ended, no fixed end date.
- **Extension Contract** — additional fields: Extension Start Date, Extension End Date, Extension Order Number, Extension Reason.

### 8.2 Department Information
Department Name, Office Address, Contact Person, Phone Number, Email, GSTIN No.

### 8.3 Financial Details
Contract Value, Security Deposit, EMD Amount.

### 8.4 Fixed Deposit

**Linkage (confirmed via `MyNotes`):** FD is issued against a **Work Order**, not the tender directly.

**Data model (build-time interpretation):** implemented as fields embedded directly on the Work Order record, not a separate collection/table — matches the prototype's single inline "Fixed Deposit Details" section per Work Order, and the single `FD Status` field (§8.4 below) implies one FD per Work Order rather than a history of several. The "Fixed Deposits" tab/view is a filtered list of Work Orders that have FD fields set, not an independent data source. Confirm this is correct — if a Work Order can have multiple FDs over its life (e.g. sequential renewals each kept as its own record), this needs to become a proper sub-collection instead.

**Tender/Work Order reference fields:**
Tender Number, Tender Name, Work Order Number, Department Name, Office Name, Contract Start Date, Contract End Date (or "till next tender"), Project Status (Running/Closed).

**FD Details:**
1. FD Number
2. Bank Name
3. Branch Name
4. FD Amount
5. FD Issue Date
6. FD Maturity Date
7. Interest Rate
8. FD Scan Copy Upload
9. FD Status (Active / Released / Renewed)

**Alerts & Reminders (automatic):**
1. FD maturity within 30 days
2. Expired FD
3. FD release pending after project completion
4. Renewal required — implemented as a consequence of items 1–2 (a maturing/expired FD is what prompts a renewal) rather than a separate stored flag; confirm if a distinct "renewal requested" state is actually needed.

**Dashboard (§8.1, Work Orders tab) — build-time expansion:** the source only listed one dashboard combining Work Order and FD stats (5 items, reproduced below under "Fixed Deposits tab" except the first). Split into two tabs matching the prototype's actual two-tab layout, and the Work Orders tab's stats were filled in from the prototype rather than the source (which didn't specify Work-Order-tab stats beyond the mislabeled item below) — confirm these 4 are correct:
- ~~Total Active Tenders~~ → **Active Work Orders** (count, `Status = Active`) — the source label doesn't match its own module (§8 is Work Orders, not Tenders) and is almost certainly a copy-paste artifact from §7; corrected to match the prototype. Flag if "Total Active Tenders" was actually intended literally.
- Expiring in 60 Days (count) — from the prototype; matches the "Alerts & Reminders" intent above but wasn't itself in the source dashboard list.
- Total Contract Value (₹) — from the prototype.
- Under Extension (count) — from the prototype.

**Dashboard (§8.4, Fixed Deposits tab):**
- Total FD Submitted (₹)
- Pending FD Return (₹)
- FD Expiring This Month (count)
- FD Released This Year (₹)

---

## 9. Supporting Modules

### 9.1 Employee Database (own staff)

**Dashboard:** Total Employees, Active Employees, New Appointments.

**Basic Information:** Employee ID, Full Name, Photo, Gender, Date of Birth, Mobile Number, Alternate Number, Email ID, Current Address, Permanent Address, City, State, PIN Code.

**Identity Details:** Aadhaar Number, PAN Number.

**Appointment / Job Information:** Date of Appointment, Joining Date, Department, Designation, Employee Type (Permanent / Temporary / Contract), Branch/Office Location, Reporting Manager, Work Status (Active / Inactive / Resigned / Retired / Contract Closed).

**Document Upload:** Aadhaar Card, PAN Card, Passport Photo.

**Search & Filter (must-have):** Employee name, Employee ID, Mobile number, Aadhaar number.

### 9.2 Resume / Candidate Database (manpower pool for placement)

This is a distinct database from §9.1 — candidates for placement roles (e.g., against staffing/facility-management work orders), not OfficeAI's own staff.

**Personal Information:** Candidate ID (auto), Full Name, Mobile Number, Alternate Number, Referred By, WhatsApp Number, Date of Birth, Age (auto-calculated), Gender, Marital Status.

**Address Information:** Village, City/Town, Taluk, District, State, Pincode.

**Education Details:** SSLC, PUC, ITI, Diploma, Degree, BE/BTech, MBA, Other.

**Category / Post applied for:** Security, Computer Operator, Receptionist, Office Assistant, Electrician, Plumber, Mechanic, Engineer, Housekeeping, Gardener, Helper, Labour.

**Experience:** Fresher / Experienced.

**Languages known (multi-select):** Kannada, English, Hindi, Others.

**Physical Information (security-guard roles only):** Height, Ex-Serviceman (Yes/No).

**Document Storage:** Resume (file).

**Search filters:** Name, Qualification, District, Taluk.

**Dashboard:** Total Candidates, plus per-category counts (e.g., Security, Housekeeping) and "Added This Month" — prototype groups by category rather than district. **Confirm** this is the desired grouping, or whether district should also be surfaced given it's a search filter.

**Confirmed non-requirement:** No job-posting storage, no resume-to-job matching (§1.2).

### 9.3 Inventory

**As specified, this is minimal:** a flat list of Item, Size, Qty (e.g., Uniform — S/M/L, Cap — S/M/L). No issue/return tracking, no assignment to employee, no reorder threshold, no stock-in/stock-out transaction log is defined in the source.

**Open question — this sheet is clearly a stub (3 rows).** Recommend clarifying before building: is this (a) a simple current-stock-on-hand list, or (b) does it need transactional tracking (who was issued what uniform, when, quantity in/out, low-stock alerts) similar to the Alerts/Reports pattern used in every other module? Given every other module in this workbook has Dashboard + Search + Alerts sections and Inventory has none, it's likely still unplanned rather than intentionally minimal.

### 9.4 Vehicle Insurance (agency/sales module)

This module manages the organization's own book of insurance customers and policies sold — not company-owned vehicles.

**Dashboard:** Total active policies; Policies expiring in 7 / 15 / 30 / 60 days; Renewals completed this month; Premium collected.

**Customer Management:** Customer name, Mobile number, Email, Address, Aadhaar/PAN (optional), Notes.

**Vehicle Management:** Vehicle number, RC details, Vehicle type (Bike / Car / Bus / Truck / Taxi / Auto), Make and model, Manufacturing year, Engine and chassis number, Financer details.

**Insurance Policy:** Insurance company, Policy number, Policy type (Third Party / Comprehensive), IDV, NCB, Premium, Commission, Start date, Expiry date, Policy PDF upload.

**Automatic Renewal System:** Show policies due in next 60/30/15/7 days; send reminders; generate a daily follow-up list.

**Search by:** Vehicle number, Customer name, Mobile number, Policy number.

**Reports:** Monthly renewals, Pending renewals, Daily follow-ups.

**Extra features called out explicitly:** One-tap WhatsApp reminder, One-tap phone call, Data export to Excel.

### 9.5 EPF Consultancy ("Classic Consultancy")

A client-facing case-management module for a consultancy that files EPF-related government services on behalf of external clients — functionally closer to a small CRM than a document register.

#### 9.5.1 Dashboard
Total Clients, Today's Applications, Pending Cases, Completed Cases, Today's Income, Today's Follow-ups, Renewal Alerts.

#### 9.5.2 Client Management
**Personal Details:** Client ID (auto), Name, Father's Name, Mobile No, Alternate Mobile, Email, Address, Aadhaar Number, PAN Number, DOB, Gender.
**Employment Details:** UAN Number, Previous Company, Current Company, DOJ, Exit Date, Member ID.

#### 9.5.3 Services offered (selectable list, not free text — explicitly requested to avoid manual re-typing)
PF Withdrawal (Form 19), Advance (Form 31), Pension (Form 10C), Transfer Claim, Joint Declaration, KYC Update, UAN Activation, Pension Certificate, Grievance, Name Correction, DOB Correction, Mobile Update, Employer Correction, Other Services.

#### 9.5.4 Case Tracking (workflow, color-coded by status)
`New Client → Documents Received → Application Submitted → EPFO Processing → Approved → Payment Credited → Fees Collected → Completed`

Status colors: 🟡 Pending · 🔵 Processing · 🟢 Completed · 🔴 Rejected.

#### 9.5.5 Document Manager
Upload & permanently retain: Aadhaar, PAN, Passbook, UAN Screenshot, Cheque, Claim PDF, Payment Screenshot.

#### 9.5.6 Follow-up
Per-case follow-up log (client, service, status, date) — e.g. "Rahul — PF Withdrawal — Applied — 25 Jun 2026."

#### 9.5.7 Income
Per-client fee tracking: Client, Service, Fee, Paid, Pending.
**Reports:** Daily income, Monthly income, Yearly income, Profit report.

#### 9.5.8 Search
By Name, Mobile, Aadhaar, PAN, UAN — "everything appears instantly" (implies an indexed/fast local or server-side lookup, not a report-generation-style search).

#### 9.5.9 Reports
Daily report: New Clients, Claims Applied, Approved, Pending, Income — counts for the day.

**Note:** the source sheet labels modules 1–7 then jumps to "Module 9 - Reports" — Module 8 is not present in the source. Flagging in case it was dropped by mistake (confirm with Vishwas whether a Module 8 was intended).

---

## 10. Audit Logging

Referenced in §4 ("View audit logs" — Admin only) but not elaborated in the source spreadsheet. Recommended minimum scope (confirm):
- Logged events: document/record upload, download, delete, category change, user role/status change, sign-in.
- Fields per entry: actor, action, target record, timestamp, module/task-group context, result.
- Append-only (e.g., written via Cloud Function, not client-writable).

---

## 11. Non-Functional Requirements (recommended — not specified in source)

- **Security:** Firestore/Storage security rules must independently enforce RBAC (§4); signed URLs for file downloads rather than public links — especially relevant given Aadhaar/PAN/financial data across Employee, Resume, Vehicle Insurance, and EPF modules. **Known gap (found during Phase 1 build):** Storage rules cannot currently re-check the caller's Firestore role — the documented "cross-service" `firestore.get()` call from Storage rules evaluated to false for every user in practice (all uploads got `[firebase_storage/unauthorized]` regardless of role), so Storage-layer role checks were dropped in favor of `signedIn()` only, relying on (a) the app UI restricting upload/delete to the right roles and (b) Firestore's own (same-service, reliably-working) `canManageDocuments()` rule gating whether an uploaded file can ever be linked to a real record. Restoring a hard role check at the Storage layer needs either Cloud Functions issuing custom claims (blocked on confirming Blaze billing, see §0.1-adjacent Phase 1 notes) or a working cross-service rule — flag for a security-hardening pass once Cloud Functions are available.
- **WhatsApp integration:** two modules (Inward/Outward §6.6, Tender-EMD §7.8) and one (Vehicle Insurance §9.4) explicitly call for WhatsApp sharing/reminders. **Resolved by prototype:** deep-linking to WhatsApp with a pre-filled message and an "Open WhatsApp" confirmation step (no Business API). Matches the "one-click" / "one-tap" phrasing used throughout and is the simpler mechanism. Confirm this as final with the stakeholder.
- **Performance:** paginate long lists (dashboards, search results); target realistic response times for search — confirm SLA.
- **Backup/retention:** confirm required policy, especially for financial (FD, EMD, EPF income) and identity documents (Aadhaar/PAN).
- **Accessibility/localization:** Resume module explicitly tracks candidate language proficiency (Kannada/English/Hindi) — confirm if the **app UI itself** needs multilingual support, or if this is only a candidate-attribute field.

---

## 12. Open Questions (consolidated)

1. Should Vehicle Insurance and EPF Consultancy be scoped as part of OfficeAI at all, or as separate apps sharing infrastructure? (§0)
2. Module-level access control beyond the 3-role matrix, given client financial/PII data in Vehicle Insurance and EPF modules, and identity documents in Employee/Resume modules. **Still open** — the prototype's role gating (`data-min-role`) applies uniformly across all modules; it does not give Vehicle Insurance/EPF/Employee data any additional protection beyond the flat 3-role matrix. (§4.1)
3. ~~Final navigation/IA~~ — **prototype proposes** all 8 modules as top-level nav items, with Deposits split (EMD under Tender-EMD, FD under Work Orders) rather than combined. Needs stakeholder confirmation, especially the Deposits split vs. `MyNotes` item 5's single "Deposits" tab. (§3)
4. Is additional in-app login (beyond Firebase email/password) required? Asked in source, left unanswered. Prototype only implements Firebase-style email/password. (§5)
5. Full inward document type list — only "Work Order" was given as an example; likely incomplete. (§6.4)
6. Inventory module — is the 3-row spec final (simple stock list) or does it need transactional tracking (issue/return, low-stock alerts)? It's the only module in the workbook with no Dashboard/Search/Alerts section defined; the prototype flags this in-app rather than resolving it. (§9.3)
7. ~~WhatsApp integration mechanism~~ — **resolved by prototype:** deep-link with pre-filled message, not Business API. Confirm as final. (§11)
8. EPF module: "Module 8" is missing between Module 7 (Search) and Module 9 (Reports) in the source — intentional or dropped? (§9.5.9)
9. **New:** should the cross-module home Dashboard (§5.1) and its "Recent activity" feed be visible to all roles, or role-gated like the Audit Log? Not specified in source. (§5.1)
10. **New:** scope and behavior of the global search box (§3.1) — which record types, and where results should route. Not specified in source. (§3.1)

---

## 13. Change Log

**v10 (this revision) — account-status security hardening (§4):**
- Added a third account status, `pending`, and made it the default for self-registered accounts (was `active`). Prompted by the question "if I publish the code to GitHub, do people get access to my Firestore data?" — the honest answer surfaced that self-registration + immediate `active` status meant anyone with the (intentionally public) Firebase config could self-register and read business data with no admin involvement. Manage Users now shows a "Pending approval" state with an Approve action; signed-in-but-not-active users get a clear "awaiting approval" / "disabled" screen instead of a raw Firestore permission error.

**v9 (prior revision) — App Version Gate added (§5.2):**
- New admin-configurable min/max app-version range, enforced before login, since standalone builds (e.g. Windows `.exe` handed to a customer) have no auto-update mechanism. Not from the source spreadsheet or prototype — requested during Phase 2 implementation.
- Also registered Windows as a real Firebase platform (`flutterfire configure` re-run including `windows`) — Phase 1 had assumed FlutterFire's Auth/Firestore/Storage plugins lacked Windows support and skipped it; that assumption was outdated, the plugins already ship a Windows implementation.

**v8 (prior revision) — Phase 2: Tender-EMD (§7) and Work Orders & Fixed Deposits (§8) built:**
- §7.6: documented the "EMD validity" date ambiguity and its resolution (optional `EMD Valid Until` field).
- §7: documented that `Refund Status` includes `Forfeited` (not explicit in the source field list).
- §8.4: documented that Fixed Deposit is embedded on the Work Order record, not a separate collection — one FD per Work Order.
- §8.1/§8.4: corrected "Total Active Tenders" to "Active Work Orders" (source label mismatch), and documented that the Work Orders tab's other 3 dashboard stats came from the prototype, not the source spreadsheet's dashboard list.
- §5.1: restored the EMD Pending Refund / FD Maturing (30 days) home-dashboard tiles that Phase 1 deliberately omitted (no real data existed yet); the "Activity by Task Group" chart now shows real Tender-EMD, Work Orders, and Fixed Deposit bars.

**v7 (prior revision) — bug fixes found during Phase 1 testing:**
- §11 Security: documented that Storage-layer role checks don't work via cross-service `firestore.get()` in practice (all uploads were unauthorized regardless of role) — Storage rules now check only `signedIn()`, with role enforcement resting on the app UI and Firestore's own rules.
- Fixed a bug where creating an Inward/Outward entry *with a file attached* silently failed to save at all (a `FieldValue`/`Timestamp` type-cast crash in `IoRepository.create()`, thrown before the Firestore write).

**v6 (prior revision) — corrected Manager rank per stakeholder direction:**
- Moved **Manager** (§4) above Power User (was below it in v5) — Manager now inherits every Power User document-management capability, plus the "Seen" acknowledgement toggle called out explicitly.

**v5 (prior revision) — build-time addition, requested during Phase 1 implementation:**
- Added a 4th role, **Manager** (§4), ranked between General User and Power User — a reviewer/acknowledgement role, not from the source spreadsheet or prototype.
- Added a **Seen** field to Inward (§6.2 item 11) and Outward (§6.3 item 11) entries: a boolean acknowledgement flag toggled by Manager/Power User/Admin, so other users can confirm a Manager has reviewed a document. General Users see a read-only indicator.
- Flagged the Manager/Power User rank ordering as a build-time judgment call needing stakeholder confirmation (§4).

**v4 (prior revision) — reviewed against `docs/prototype.html`:**
- Added §0.1 summarizing decisions the prototype made that need stakeholder confirmation.
- Added §3.1 (Global Search) and updated §3 to document the prototype's implemented navigation/IA, flagging its Deposits split as a deviation from `MyNotes` item 5.
- Added new §5.1 (Home Dashboard) — a cross-module landing dashboard not present in the source spreadsheet.
- Updated §9.2 Resume dashboard to note the prototype's category-based grouping (previously TBD).
- Updated §11 to mark the WhatsApp deep-link mechanism as resolved by the prototype.
- Updated §12 open questions: resolved/narrowed items 3 and 7, sharpened item 2's gap, added items 9–10 for the new Dashboard and global search.

**v3 (prior revision):**
- Replaced all placeholder/assumed field lists with actual fields from the source spreadsheet.
- Corrected three module misreadings from v2: Inventory (uniform stock, not IT assets), Vehicle Insurance (agency/sales CRM, not fleet management), EPF (external client consultancy, not internal payroll).
- Added confirmed business rule: FD is issued against a Work Order, not a Tender; EMD is standalone and returned on Work Order issuance.
- Folded in answers from the `MyNotes` sheet (document types, resume-matching non-requirement) and flagged the questions that were asked there but left unanswered.
- Added §3 (navigation) and §12 (consolidated open questions) as new sections.

**v2 (prior revision):** Fixed numbering/duplication issues in the original draft, added NFR/audit-logging/account-provisioning sections, and marked all field-level content as draft pending the spreadsheet (now superseded by v3).