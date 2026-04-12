# User Types & Roles

## Overview

The system defines two primary user roles — **Doctors (Admin)** and **Assistants (User)** — each with distinct permissions and capabilities. Both roles are governed by a shared **Security & Compliance** framework.

---

## 1. Doctors (Admin)

Doctors hold full administrative control over the system.

### 1.1 Full Access Permissions

| Permission | Description |
|---|---|
| View all patients | Access the complete patient list across the system |
| Read all records | View all medical records without restriction |
| Write / edit all data | Create and modify any data in the system |
| Delete any patient | Remove patient records from the system |
| Analytics dashboard | Access system-wide analytics and reporting |

### 1.2 Administrative Functions

| Function | Description |
|---|---|
| User management | Create, edit, and deactivate user accounts |
| System configuration | Manage system settings and configurations |
| Audit logs access | View a full audit trail of system activity |

### 1.3 Clinical Capabilities

| Capability | Description |
|---|---|
| Override restrictions | Bypass access restrictions when clinically necessary |
| Approve critical changes | Authorise sensitive or critical system changes |
| Access analytics dashboard | Review clinical analytics and performance data |

---

## 2. Assistants (User)

Assistants have limited, scoped access focused on day-to-day data entry and patient management.

### 2.1 Limited Access Permissions

| Permission | Description |
|---|---|
| View own patients only | Can only see patients assigned to them |
| Read own records | Access restricted to their own patient records |
| Write new entries | Can create new records and entries |
| Delete own patients | Can remove only their own patient entries |

### 2.2 Workflow Restrictions

| Restriction | Description |
|---|---|
| Cannot access others' data | No visibility into other users' patients or records |
| Filtered patient list | Patient list is scoped to assigned patients only |
| Limited reports | Access to a restricted subset of reports |

### 2.3 Data Entry Functions

| Function | Description |
|---|---|
| Add new patients | Register new patients in the system |
| Update patient info | Edit existing patient details |
| Schedule appointments | Book and manage patient appointments |

---

## 3. Security & Compliance

Applies to **all user roles** across the system.

| Control | Description |
|---|---|
| Authentication | Secure login and identity verification for all users |
| Role-based access control | Permissions enforced strictly by assigned role |
| Data privacy rules | Patient data handled in accordance with privacy regulations |
| Activity tracking | All user actions logged for audit and monitoring purposes |

---

## Summary Table

| Feature | Doctors (Admin) | Assistants (User) |
|---|:---:|:---:|
| View all patients | ✅ | ❌ |
| View own patients | ✅ | ✅ |
| Read all records | ✅ | ❌ |
| Read own records | ✅ | ✅ |
| Write / edit data | ✅ | ✅ (own only) |
| Delete any patient | ✅ | ❌ |
| Delete own patients | ✅ | ✅ |
| User management | ✅ | ❌ |
| System configuration | ✅ | ❌ |
| Audit logs access | ✅ | ❌ |
| Override restrictions | ✅ | ❌ |
| Approve critical changes | ✅ | ❌ |
| Add new patients | ✅ | ✅ |
| Update patient info | ✅ | ✅ |
| Schedule appointments | ✅ | ✅ |
| Analytics dashboard | ✅ | ❌ |
| Authentication | ✅ | ✅ |
| Role-based access control | ✅ | ✅ |
| Data privacy rules | ✅ | ✅ |
| Activity tracking | ✅ | ✅ |
