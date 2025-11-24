---

# **UserOnboarding**

Utility tools to quickly create Salesforce users with all necessary access & permissions.

---

# **UserCloneService**

### *An Open-Source Apex REST + Invocable Service for Cloning Salesforce Users*

This service allows Salesforce Admins to **clone an existing user (“mirror user”)** and automatically replicate their:

* Profile & Role
* Locale, Timezone, Encoding, Language settings
* Permission Set Assignments
* Permission Set Group Assignments
* Permission Set License Assignments
* Public/Queue Group Memberships
* Chatter Group Memberships
* Managed Package Licenses

It exposes:

* **Apex REST API**
* **Flow Invocable Action**
* **Aura-enabled utility methods**

> ⚠️ **Security Warning:** This code is intended for **admin-level automation only**. Never expose it to external callers without OAuth and proper permission restrictions.

---

# 🧩 Features

* Clone a user using **Name, Username, Email, or Alias**
* Auto-generate valid **Alias** and **Username** from email
* Bulk-safe Flow invocable method (supports list input)
* Dynamic handling of `PermissionSetGroupAssignment`
* Detailed status & messages in REST + Flow responses

---

# 🏗 Class Overview

**Class:** `UserCloneService`
**Annotation:** `@RestResource(urlMapping='/user-clone')`
**Sharing:** `with sharing`

## **Entry Points**

### **1. REST API**

* **Method:** `@HttpPost postCloneUser()`
* **URL:**

  ```
  POST /services/apexrest/user-clone
  ```

### **2. Flow Invocable**

```apex
@InvocableMethod
cloneUserInvocable(List<CloneRequest> requests)
```

### **3. Aura-Enabled Methods**

* `findMirrorUserId(String mirrorUserName)`
* `getMirrorUserAssets(Id mirrorUserId)`
* `cloneMirrorUser(String newUserName, String newUserEmail, String mirrorUserName)`

---

# 💾 Data Contracts

### **CloneRequest (input)**

```json
{
  "newUserName": "John Doe",
  "newUserEmail": "john.doe@example.com",
  "mirrorUserName": "existing.user@example.com"
}
```

### **CloneResponse (output)**

```json
{
  "mirrorUserId": "005XXXXXXXXXXXX",
  "newUserId": "005YYYYYYYYYYYY",
  "status": "SUCCESS",
  "message": "User cloned."
}
```

Error response example:

```json
{
  "mirrorUserId": null,
  "newUserId": null,
  "status": "ERROR",
  "message": "Mirror user not found for: foo@bar.com"
}
```

---

# 🔌 REST API Usage

### **Endpoint**

```
POST /services/apexrest/user-clone
```

### **Headers**

```
Authorization: Bearer <ACCESS_TOKEN>
Content-Type: application/json
```

### **Example cURL Request**

```bash
curl -X POST \
  https://yourInstance.salesforce.com/services/apexrest/user-clone \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "newUserName": "Jane Doe",
    "newUserEmail": "jane.doe@example.com",
    "mirrorUserName": "admin@example.com"
  }'
```

---

# 🌐 Postman Collection

Save the JSON below as `UserCloneService.postman_collection.json` and import in Postman:

```json
{
  "info": {
    "name": "Salesforce UserCloneService",
    "_postman_id": "00000000-0000-0000-0000-000000000001",
    "description": "Postman collection to test the UserCloneService Apex REST endpoint for cloning users.",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Clone User (POST /user-clone)",
      "request": {
        "method": "POST",
        "header": [
          { "key": "Authorization", "value": "Bearer {{access_token}}", "type": "text" },
          { "key": "Content-Type", "value": "application/json", "type": "text" }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"newUserName\": \"Jane Doe\",\n  \"newUserEmail\": \"jane.doe@example.com\",\n  \"mirrorUserName\": \"admin@example.com\"\n}"
        },
        "url": {
          "raw": "{{instance_url}}/services/apexrest/user-clone",
          "host": ["{{instance_url}}"],
          "path": ["services", "apexrest", "user-clone"]
        }
      }
    }
  ],
  "variable": [
    { "key": "instance_url", "value": "https://yourInstance.my.salesforce.com" },
    { "key": "access_token", "value": "<paste OAuth access token here>" }
  ]
}
```

---

# 🔁 Flow Usage Guide

### **Invocable Method**

```apex
@InvocableMethod(
    label='Clone User from Mirror',
    description='Clones a user based on a mirror user and copies assignments.'
)
public static List<CloneResponse> cloneUserInvocable(List<CloneRequest> requests)
```

### **Inputs**

* `newUserName`
* `newUserEmail`
* `mirrorUserName`

### **Outputs**

* `mirrorUserId`
* `newUserId`
* `status`
* `message`

---

# 🧱 Example Flow Design

**Use Case:**
Automatically clone a user when a “User Request” record is created.

### **High-Level Steps**

1. **Start** – Record-triggered or screen flow
2. **Get Mirror User Identifier**
3. **Apex Action → Clone User from Mirror**
4. **Map Inputs → CloneRequest fields**
5. **Map Outputs → Flow variables**
6. **Decision:**

   * If `status == 'SUCCESS'`: Update record with `newUserId`
   * Otherwise: Store/show error message
7. **End**

---

# 🔐 Security Considerations

* Class runs **with sharing**
* Should only be invoked by:

  * System administrators
  * Controlled automation integrations
* REST endpoint requires OAuth access token
* Partial insert used for permissions & licenses (avoids full failure)

---

# 🚀 Deployment

1. Add `UserCloneService.cls` and `.cls-meta.xml` to your SFDX project.
2. Deploy:

   ```bash
   sfdx force:source:deploy -p force-app/main/default/classes/UserCloneService.cls
   ```
3. Ensure your automation user has access to:

   * Apex class
   * User object
   * PermissionSetAssignment
   * GroupMember
   * CollaborationGroupMember
   * UserPackageLicense
4. Test with:

   ```bash
   sfdx force:apex:test:run -n UserCloneServiceTest -w 10
   ```

---

# 🙌 Contributing

1. Fork the repository
2. Create a feature branch
3. Add or update tests
4. Submit a pull request with a clear description

---
