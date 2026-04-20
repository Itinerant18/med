# Healthcare Management Platform
## Feature Overview — Client Presentation

---

## Overview

This platform is a role-based healthcare management system designed to streamline patient data management, inter-team communication, and clinical workflows. It introduces three clearly defined user roles — **Head Doctor**, **Doctor**, and **Agent** — each with tailored access, responsibilities, and tools.

---

## 👤 Role 1: Head Doctor (Platform Administrator)

The Head Doctor serves as the top-level authority on the platform, overseeing all user activity and maintaining full control over who can access the system.

### Key Features

- **Approval Dashboard**
  A dedicated, exclusive interface to review and approve or reject all incoming registration requests from Doctors and Agents. No new user can access the platform without this explicit approval.

- **Registration Alerts**
  Instant notifications whenever a new Doctor or Agent submits a registration — ensuring no request goes unnoticed or unattended.

- **User Management Console**
  A full overview of all active Doctors and Agents on the platform, with the ability to deactivate or revoke access at any time.

- **Full Doctor Access**
  In addition to administrative privileges, the Head Doctor has complete access to all standard Doctor features listed below.

---

## 🩺 Role 2: Doctor

Doctors are clinical professionals who use the platform to review patient data, manage records, and coordinate follow-up actions with Agents.

### Key Features

- **Unified Doctor Dashboard**
  A clean, standardized workspace shared across all approved Doctors. Every Doctor has an equal standing — no Doctor holds authority over another on the platform.

- **Patient Database Access**
  Full ability to search, view, and manage all patient profiles and records that have been entered into the system by Agents.

- **Follow-Up Assignment**
  Doctors can flag specific patient profiles and assign targeted follow-up tasks directly to the responsible Agent — keeping communication structured and accountable.

- **Medical Record Management**
  Tools to add clinical notes, update patient status, and finalize records after reviewing Agent-submitted data.

- **Self-Registration with Approval Flow**
  Doctors can register themselves through a dedicated portal. Their account remains in a **"Pending"** state until the Head Doctor reviews and approves their request.

---

## 🧑‍💼 Role 3: Agent

Agents are the primary data-entry personnel on the platform. Their workspace is purpose-built for uploading patient information and managing assigned follow-up responsibilities.

### Key Features

- **Private Patient View**
  Agents can only see the patient profiles they have personally uploaded — ensuring complete data privacy and preventing unauthorized browsing of the general patient database.

- **Patient Data Entry Portal**
  A structured and intuitive interface to input new patient records, including demographics, medical history, and supporting documents.

- **Follow-Up & Task Inbox**
  A dedicated inbox where Agents receive follow-up tasks assigned to them by any Doctor. All notifications are clearly organized for easy action.

- **Task Status Management**
  Agents can update the status of assigned tasks — marking them as **"In Progress"** or **"Completed"** — keeping Doctors informed in real time.

- **Self-Registration with Approval Flow**
  Agents register through their own portal and must receive Head Doctor approval before gaining access to any data entry or patient management tools.

---

## ⚙️ Platform-Wide Capabilities

These features operate across all roles and ensure the platform runs securely and intelligently.

| Capability | Description |
|---|---|
| **Role-Based Access Control** | Every user sees only what their role permits. Access boundaries are enforced at every level of the platform. |
| **Patient Ownership Tracking** | Every patient record is permanently linked to the Agent who created it, enabling accurate data attribution and the private patient view. |
| **Smart Notification Routing** | Notifications are delivered precisely — registration alerts go only to the Head Doctor; follow-up tasks go only to the assigned Agent. |
| **Pending Approval State** | New registrations are securely held in a pending state, preventing unauthorized access before Head Doctor review. |

---

## Summary of Role Access

| Feature | Head Doctor | Doctor | Agent |
|---|:---:|:---:|:---:|
| Approve / Reject Registrations | ✅ | ❌ | ❌ |
| View All Patients | ✅ | ✅ | ❌ |
| View Own Uploaded Patients Only | ✅ | ✅ | ✅ |
| Add Clinical Notes & Update Records | ✅ | ✅ | ❌ |
| Assign Follow-Up Tasks to Agents | ✅ | ✅ | ❌ |
| Receive & Manage Follow-Up Tasks | ❌ | ❌ | ✅ |
| Upload New Patient Data | ❌ | ❌ | ✅ |
| Deactivate User Accounts | ✅ | ❌ | ❌ |
| Receive Registration Alerts | ✅ | ❌ | ❌ |

---

## User Flow Diagrams

### 🔑 Legend

| Colour | Role |
|---|---|
| 🟣 Purple | Head Doctor |
| 🟢 Teal | Doctor |
| 🟠 Coral | Agent |
| ⬜ Gray | Shared / System |

---

### 👤 Head Doctor Flow

```
[ Platform Login ]
        │
        ▼
┌─────────────────────────────────┐
│       Admin Dashboard           │
│  Approval alerts + global view  │  ◀── 🟣 Head Doctor only
└─────────────────────────────────┘
        │
        ▼
  Pending registration?
  ┌─────┴──────┐
 Yes           No
  │             │
  ▼             ▼
┌──────────────────┐    ┌──────────────────────┐
│ Approval Dashboard│    │  User Management     │
│ Review request   │    │  View / deactivate   │
└──────────────────┘    └──────────────────────┘
        │
        ▼
  Approve or Reject?
  ┌─────┴──────┐
Approve      Reject
  │             │
  ▼             ▼
[ User        [ Request
 Activated ]   Denied ]

        │
        ▼
  + All Doctor features (see below)
```

---

### 🩺 Doctor Flow

```
[ Self-Registration Portal ]
        │
        ▼
[ Account — Pending Approval ]
        │
        ▼
[ Head Doctor Approves ]
        │
        ▼
┌─────────────────────────────┐
│      Doctor Dashboard       │  ◀── 🟢 Approved Doctors only
│     Unified workspace       │
└─────────────────────────────┘
        │
   ┌────┼────────────────┐
   │    │                │
   ▼    ▼                ▼
┌──────────┐  ┌──────────────────┐  ┌───────────────────┐
│ Patient  │  │ Medical Record   │  │  Assign Follow-Up │
│ Database │  │ Tools            │  │  Flag patient →   │
│ Search,  │  │ Notes, status,   │  │  specific Agent   │
│ view,    │  │ finalize         │  └───────────────────┘
│ manage   │  └──────────────────┘          │
└──────────┘                                ▼
                                   [ Agent Notified ↓ ]
```

---

### 🧑‍💼 Agent Flow

```
[ Self-Registration Portal ]
        │
        ▼
[ Account — Pending Approval ]
        │
        ▼
[ Head Doctor Approves ]
        │
        ▼
┌─────────────────────────────┐
│      Agent Dashboard        │  ◀── 🟠 Approved Agents only
│   Private silo workspace    │
└─────────────────────────────┘
        │
   ┌────┴────────────────┐
   │                     │
   ▼                     ▼
┌──────────────────┐  ┌──────────────────────────┐
│ Data Entry Portal│  │   Follow-Up Inbox         │
│ Upload patient   │  │   Receive tasks assigned  │
│ records          │  │   by Doctors              │
└──────────────────┘  └──────────────────────────┘
                                  │
                                  ▼
                       [ Mark: In Progress / Done ]
```

---

### 🔄 Cross-Role Interaction Summary

```
HEAD DOCTOR                DOCTOR                    AGENT
─────────────              ──────────────            ──────────────
Receives registration  →   Registers &               Registers &
alert                      awaits approval            awaits approval
      │
      ▼
Approves / Rejects ──────────────────────────────────────────────▶
                           Accesses dashboard         Accesses dashboard
                                  │                         │
                           Assigns follow-up ──────▶  Receives task in
                           to specific Agent           Follow-Up Inbox
                                                             │
                                                      Updates task status
                                                      (In Progress / Done)
                                  │
                           Reviews patient records
                           (uploaded by Agents)
```

---


