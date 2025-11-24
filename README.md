# UserOnboarding
Provides an utility to quickly create user with necessary access &amp; permissions

# UserCloneService

Open-source Apex REST + Invocable service for **cloning Salesforce Users** based on a “mirror” user.

The service:

- Creates a new user using a source (“mirror”) user’s **profile, role, and locale settings**
- Replicates the mirror user’s:
  - Permission Set Assignments
  - Permission Set Group Assignments (if available in the org)
  - Permission Set License Assignments
  - Public/Queue Group Memberships
  - Chatter Group Memberships
  - Managed Package Licenses
- Exposes:
  - A REST API endpoint
  - An Invocable Method (for Flow)
  - Aura-enabled methods (for UI integrations)

> ⚠️ This code is intended for **admin-level automation**. Do not expose it to untrusted callers without additional security controls.

---

## Features

- Clone a user using **Name, Username, Email, or Alias** as the mirror identifier
- Automatically derive a valid **Alias** and **Username** from the new user’s email
- Bulk-safe pattern for Flow (invocable method accepts a list of requests)
- Dynamic handling of `PermissionSetGroupAssignment` (works in orgs without permission set groups)
- Detailed status and message output for REST and Flow

---

## Class Overview

Class: `UserCloneService`

- Annotation: `@RestResource(urlMapping='/user-clone')`
- Sharing: `with sharing`

Main entry points:

1. **REST API**
   - `@HttpPost global static void postCloneUser()`
   - URL: `/services/apexrest/user-clone`

2. **Flow Invocable**
   - `@InvocableMethod cloneUserInvocable(List<CloneRequest> requests)`

3. **Aura-enabled utility methods**
   - `@AuraEnabled(cacheable=true) findMirrorUserId(String mirrorUserName)`
   - `@AuraEnabled(cacheable=true) getMirrorUserAssets(Id mirrorUserId)`
   - `@AuraEnabled cloneMirrorUser(String newUserName, String newUserEmail, String mirrorUserName)`

---

## Data Contracts

### CloneRequest (input)

```json5
{
  "newUserName": "John Doe",
  "newUserEmail": "john.doe@example.com",
  "mirrorUserName": "existing.user@example.com"
}

