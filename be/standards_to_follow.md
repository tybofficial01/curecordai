# CurecordAI - Standards to Follow from Day One

> **Purpose:** This document is a living reference for the CurecordAI engineering, product, and legal team. Every standard listed here should be treated as a build requirement, not an afterthought.

---

## Table of Contents

1. [Data Privacy & Legal Compliance](#1-data-privacy--legal-compliance)
2. [Health Data Interoperability Standards](#2-health-data-interoperability-standards)
3. [Data Storage & Security](#3-data-storage--security)
4. [AI & Clinical Safety](#4-ai--clinical-safety)
5. [Clinic & Hospital Integration Readiness](#5-clinic--hospital-integration-readiness)
6. [App Store & Platform Requirements](#6-app-store--platform-requirements)
7. [Priority Implementation Order](#7-priority-implementation-order)
8. [Ongoing Responsibilities](#8-ongoing-responsibilities)

---

## 1. Data Privacy & Legal Compliance

### 🇵🇰 Pakistan (Primary Market - Enforce Immediately)

| Standard | What It Requires | Action Required |
|---|---|---|
| **PDPA** (Personal Data Protection Act) | User consent before data collection, right to access/delete data, breach notification, data controller appointment | Build consent flows, deletion pipeline, and breach notification process before first user |
| **PECA 2016** (Prevention of Electronic Crimes Act) | Governs unauthorized data access and breaches | Document breach response procedure; log all access |

---

### International (Build-Aligned Now, Enforce on Expansion)

| Standard | Jurisdiction | Key Requirements |
|---|---|---|
| **HIPAA** | USA | PHI protection, Business Associate Agreements (BAA), audit logs, encryption, access controls |
| **GDPR** | European Union | Explicit consent, right to erasure, data portability, privacy by design |
| **DPDP Act 2023** | India | Consent-based data processing, data fiduciary obligations |
| **NABIDH / DHA** | UAE / Gulf | Health data standards mandated by Dubai Health Authority |

> ⚠️ **GDPR applies the moment any EU resident uses the app**, regardless of where CurecordAI is based. Build GDPR-aligned consent flows from day one.

---

## 2. Health Data Interoperability Standards

These standards are non-negotiable when integrating with any clinic, hospital, lab, or external health system. Design your internal data models around these from the start.

### HL7 FHIR R4 - Most Important

> FHIR (Fast Healthcare Interoperability Resources) is the global standard for exchanging health data between systems. Every clinic, hospital, and lab integration will expect FHIR.

**Key FHIR Resources to implement for CurecordAI:**

| FHIR Resource | CurecordAI Use Case |
|---|---|
| `Patient` | User and family member demographic profiles |
| `Observation` | Extracted lab results and vitals |
| `MedicationRequest` | Extracted prescriptions |
| `Condition` | Extracted diagnoses |
| `DocumentReference` | Uploaded medical documents (PDFs, images) |
| `AllergyIntolerance` | Extracted allergy information |
| `Encounter` | Doctor visits and episodes of care |

**Action:** Design all internal database schemas to be FHIR R4-compatible, even before exposing a FHIR API.

---

### HL7 v2 - Legacy System Support

Many existing hospital and lab systems in Pakistan still use HL7 v2 messaging. Your integration layer must support both HL7 v2 and FHIR R4.

**Action:** Build an HL7 v2 parser in your integration service layer before approaching any clinic partnership.

---

### Clinical Terminology Standards

| Standard | Purpose | When to Apply |
|---|---|---|
| **ICD-11** (WHO) | Coding extracted diagnoses | Every diagnosis extracted by AI must map to an ICD-11 code |
| **LOINC** | Coding lab test names and results | Every lab result extracted must map to a LOINC code |
| **WHO ATC** | Coding medication names | Every medication extracted from a prescription must map to an ATC code |
| **SNOMED CT** | Clinical terminology for conditions and procedures | Apply when categorizing clinical findings from documents |
| **DICOM** | Medical imaging files (X-rays, MRIs, CT scans) | Support DICOM file ingestion in the document vault (future milestone) |

> **Why this matters:** When a clinic's system receives data from CurecordAI, it expects ICD-11 diagnoses, LOINC lab codes, and ATC medication codes - not plain text. Without coded data, integrations break.

---

## 3. Data Storage & Security

### Encryption - Non-Negotiable

| Layer | Standard | Requirement |
|---|---|---|
| **Data at rest** | AES-256 | All stored health data: database records, uploaded documents, backups |
| **Data in transit** | TLS 1.3 (minimum TLS 1.2) | All API calls, file transfers, user-facing connections. Never plain HTTP |
| **QR/link sharing** | End-to-end encryption | Shared health history links must be encrypted; accessible only to intended recipient during valid time window |

---

### Access Control

```
✅ Role-Based Access Control (RBAC) from day one
   - Patient (owner)
   - Family Admin (manages family vault)
   - Doctor (time-limited, read-only view via shared link)
   - CurecordAI system admin (internal, audited)

✅ Multi-Factor Authentication (MFA)
   - Required for all account logins
   - Required before sharing records or viewing sensitive data

✅ Zero-Trust Architecture
   - Never assume any internal or external request is safe
   - Verify every access request regardless of origin
```

---

### Audit Logging - Build Before First User

Every access to any patient record must be logged with:

- Who accessed it (user ID / role)
- What was accessed (record type, document ID)
- When (timestamp, timezone)
- From where (device type, IP address)
- What action was taken (view, download, share, delete)

> ⚠️ Audit logs must be **immutable** - never allow logs to be edited or deleted. Store separately from primary application data.

---

### Data Residency

| User Region | Storage Requirement |
|---|---|
| Pakistan | Store in Pakistan or compliant regional data center (AWS Bahrain / Azure UAE North as interim) |
| EU users | Store in EU-based data center (GDPR requirement) |
| Other regions | Define per-region policy before expansion |

---

### Data Retention & Deletion

- Define and document a clear data retention policy before launch
- Users must be able to **export all their data** (GDPR portability requirement)
- Users must be able to **permanently delete all their data** (GDPR right to erasure)
- After account deletion: define how long data is retained before permanent purge (recommend: 30 days grace period, then permanent deletion)
- Build the deletion pipeline **before** you need it - not after a user requests it

---

### Backup & Disaster Recovery

| Metric | Target |
|---|---|
| **RPO** (Recovery Point Objective) | Maximum 1 hour of data loss acceptable |
| **RTO** (Recovery Time Objective) | System restored within 4 hours of failure |
| **Backup frequency** | Every 6 hours minimum, daily full backup |
| **Backup encryption** | AES-256 - same standard as primary data |
| **Backup location** | Geographically separate from primary data center |

---

## 4. AI & Clinical Safety

### The Most Important Rule

> ⛔ **CurecordAI's AI assistant must never diagnose, prescribe, or recommend treatment.**

The AI assistant is an **information and organization tool**, not a clinical decision-making tool. This distinction is both a legal protection and an ethical obligation.

---

### Required AI Disclaimers

Every response from the AI health assistant must include a clear disclaimer. Suggested language:

```
This information is based on your uploaded medical records and is provided 
for informational purposes only. It is not medical advice. Please consult 
a qualified healthcare professional for clinical decisions.
```

This disclaimer must be:
- Visible on every AI response (not buried in settings or terms)
- Available in both Urdu and English
- Logged as part of the session audit trail

---

### AI Transparency Requirements

| Requirement | Why |
|---|---|
| Users must always know they are talking to an AI | Required under EU AI Act and ethical best practice |
| AI responses should cite the source document/record they are based on | Explainability - users should know which lab report or prescription the answer came from |
| Confidence levels should be communicated where relevant | Avoid presenting uncertain extractions as definitive facts |
| AI errors must have a correction/feedback mechanism | Users must be able to flag incorrect extractions |

---

### Regulatory Awareness (Future)

| Regulation | Jurisdiction | Relevance to CurecordAI |
|---|---|---|
| **EU AI Act** | EU | Classifies AI in healthcare as "high risk" - requires transparency, accuracy, and human oversight |
| **FDA SaMD** | USA | AI providing clinical insights may be classified as Software as a Medical Device |
| **MDCG Guidelines** | EU | Medical device software guidance - relevant if AI crosses into clinical decision support |

> **Design principle:** Stay clearly on the **"information and organization" side** of the line, not the **"clinical decision support"** side. This minimizes regulatory exposure in every market.

---

## 5. Clinic & Hospital Integration Readiness

Before approaching any clinic or hospital partnership, the following must be in place:

### API Security

```
✅ OAuth 2.0 / OpenID Connect - for all third-party authentication
✅ API rate limiting - prevent abuse of integration endpoints
✅ API versioning - v1/, v2/ - never break existing integrations
✅ Webhook security - signed payloads with HMAC verification
✅ Never expose raw API keys - use environment secrets management
```

---

### Legal Documents Required

| Document | Purpose | Status |
|---|---|---|
| **Data Sharing Agreement (DSA)** | Defines what data is shared, for what purpose, for how long, and liability | Prepare template before first clinic conversation |
| **Business Associate Agreement (BAA)** | Required under HIPAA for any US-connected health data | Prepare before US expansion or US system integration |
| **Privacy Policy** | User-facing, required for app store approval | Write before app submission |
| **Terms of Service** | Defines user obligations and CurecordAI liability limits | Write before app submission |
| **AI Disclaimer Policy** | Formal policy governing AI assistant limitations | Write before launch |

---

### Uptime & Reliability

> Clinics integrating with CurecordAI will require a defined Service Level Agreement (SLA).

| Metric | Minimum Target |
|---|---|
| **Uptime** | 99.9% (less than 8.7 hours downtime per year) |
| **API response time** | < 500ms for record retrieval |
| **Document processing time** | < 30 seconds for AI extraction on upload |
| **Incident response time** | < 1 hour acknowledgment, < 4 hours resolution for critical issues |

---

## 6. App Store & Platform Requirements

### Apple App Store

- Health apps must include a clear disclaimer that the app is not a medical device
- If integrating Apple HealthKit in future: must request only necessary HealthKit permissions and disclose usage clearly
- Privacy policy must be publicly accessible via a URL at time of submission
- Health data cannot be used for advertising or sold to third parties

### Google Play Store

- Health & Fitness policy prohibits using health data for advertising purposes
- Sensitive permissions (storage access for document upload) must be justified in submission
- Privacy policy URL required at submission
- Data safety form must accurately disclose what data is collected, stored, and shared

---

## 7. Priority Implementation Order

### Phase 1 - Before Any User Data Is Collected ✅

```
□ AES-256 encryption at rest
□ TLS 1.3 in transit
□ Role-Based Access Control (RBAC)
□ Multi-Factor Authentication (MFA)
□ Audit logging for all record access
□ Privacy Policy (PDPA + GDPR-aligned)
□ Terms of Service
□ AI disclaimer on every health assistant response
□ Data deletion pipeline
□ Breach notification procedure
```

### Phase 2 - Before First Clinic or Lab Integration ✅

```
□ FHIR R4 internal data models
□ ICD-11 mapping for extracted diagnoses
□ LOINC mapping for extracted lab results
□ WHO ATC mapping for extracted medications
□ HL7 v2 parser for legacy system support
□ OAuth 2.0 API authentication
□ API versioning and rate limiting
□ Data Sharing Agreement (DSA) template
□ Business Associate Agreement (BAA) template
□ Uptime SLA documentation
□ DICOM file support in document vault
```

### Phase 3 - Before International Expansion ✅

```
□ Full GDPR compliance (consent flows, right to erasure, data portability)
□ HIPAA-aligned architecture (for US market)
□ EU data residency (for EU market)
□ Per-region data residency controls
□ BAA signed with all third-party service providers handling PHI
□ EU AI Act compliance review
□ FDA SaMD assessment (if targeting US clinical features)
□ NABIDH / DHA compliance (for UAE/Gulf market)
□ Multilingual disclaimers (Urdu, Arabic, etc.)
```

---

## 8. Ongoing Responsibilities

These are not one-time tasks - they must be maintained continuously:

| Responsibility | Frequency | Owner |
|---|---|---|
| Security audit / penetration testing | Every 6 months | Engineering Lead |
| Privacy policy review | Every 12 months or on regulatory change | Legal / Founder |
| Audit log review | Monthly | Engineering Lead |
| Backup restoration test | Every 3 months | Engineering Lead |
| Dependency vulnerability scan | Every sprint | Engineering |
| AI response accuracy review | Monthly | Product Lead |
| Regulatory landscape review (PDPA updates, etc.) | Quarterly | Founder / Legal |
| Data retention enforcement | Monthly automated + quarterly manual audit | Engineering |

---

## Quick Reference Card

```
ENCRYPT EVERYTHING         → AES-256 at rest, TLS 1.3 in transit
LOG EVERYTHING             → Every record access, immutable audit trail
CODE EVERYTHING            → ICD-11, LOINC, ATC, FHIR R4
NEVER DIAGNOSE             → AI is information only, not clinical advice
CONSENT BEFORE COLLECT     → PDPA + GDPR consent flows before any data
BUILD DELETION FIRST       → Right to erasure before right to store
FHIR FROM DAY ONE          → Design data models FHIR R4-compatible now
ZERO TRUST ALWAYS          → Verify every request, trust nothing by default
DOCUMENT EVERYTHING        → DSA, BAA, Privacy Policy, Terms before launch
```

---

> **Last updated:** June 2026
> **Document owner:** CurecordAI Founding Team
> **Review frequency:** Quarterly, or immediately upon any regulatory change in Pakistan, EU, or US health data law

---

*This document is a living reference. As CurecordAI grows and regulations evolve, this document must be updated accordingly. When in doubt, default to the stricter standard.*
