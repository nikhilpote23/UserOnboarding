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

### CloneResponse (output)
{
  "mirrorUserId": "005xxxxxxxxxxxx",
  "newUserId": "005yyyyyyyyyyyy",
  "status": "SUCCESS" | "ERROR",
  "message": "User cloned." | "Error message"
}

## REST API Usage
Endpoint
POST /services/apexrest/user-clone

Headers

Authorization: Bearer <access_token>

Content-Type: application/json

Example Request
curl -X POST \
  https://yourInstance.salesforce.com/services/apexrest/user-clone \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "newUserName": "Jane Doe",
    "newUserEmail": "jane.doe@example.com",
    "mirrorUserName": "admin@example.com"
  }'

Example Success Response
{
  "mirrorUserId": "0055g00000XXXXAA0",
  "newUserId": "0055g00000YYYYAA0",
  "status": "SUCCESS",
  "message": "User cloned."
}

Example Error Response
{
  "mirrorUserId": null,
  "newUserId": null,
  "status": "ERROR",
  "message": "Mirror user not found for: foo@bar.com"
}

---
## Flow Usage

You can call the cloneUserInvocable method from Flow:

Action Type: Apex → Clone User from Mirror

Inputs:

newUserName (Text)
newUserEmail (Text)
mirrorUserName (Text)

Outputs:

mirrorUserId
newUserId
status
message

## Security Considerations

The class runs with sharing (respects record-level sharing).
You must ensure:
Only system administrators or controlled automations invoke this logic.
External access via the REST endpoint is protected by OAuth and profile/perm set restrictions.
Assigning licenses and groups might fail for some org configurations; partial insert behavior is used to avoid blocking the whole operation.

## Deployment

Add UserCloneService.cls and UserCloneService.cls-meta.xml to your SFDX project.

Deploy via:
sfdx force:source:deploy -p force-app/main/default/classes/UserCloneService.cls
Assign appropriate permissions to admins or automation user:
Apex class access
Object-level rights to User, PermissionSetAssignment, GroupMember, etc.


## Postman Collection

You can save the following as UserCloneService.postman_collection.json and import into Postman.

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
          {
            "key": "Authorization",
            "value": "Bearer {{access_token}}",
            "type": "text"
          },
          {
            "key": "Content-Type",
            "value": "application/json",
            "type": "text"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"newUserName\": \"Jane Doe\",\n  \"newUserEmail\": \"jane.doe@example.com\",\n  \"mirrorUserName\": \"admin@example.com\"\n}"
        },
        "url": {
          "raw": "{{instance_url}}/services/apexrest/user-clone",
          "host": [
            "{{instance_url}}"
          ],
          "path": [
            "services",
            "apexrest",
            "user-clone"
          ]
        }
      },
      "response": []
    }
  ],
  "variable": [
    {
      "key": "instance_url",
      "value": "https://yourInstance.my.salesforce.com"
    },
    {
      "key": "access_token",
      "value": "<paste OAuth access token here>"
    }
  ]
}


## Usage:

Obtain an OAuth access token (e.g., via Workbench, Postman OAuth 2.0, or your integration).
In Postman:
Set instance_url (e.g., https://mydomain.my.salesforce.com)
Set access_token.
Send the “Clone User” request.

## Flow Usage Documentation

# Flow Usage – UserCloneService

This document describes how to use the `UserCloneService.cloneUserInvocable` method from Salesforce Flow to automate user cloning.

# Apex Action in Flow

The class exposes an **Invocable Method**:

```apex
@InvocableMethod(
    label='Clone User from Mirror'
    description='Clones a user based on a mirror user and copies assignments.'
)
public static List<CloneResponse> cloneUserInvocable(List<CloneRequest> requests)

Inputs (CloneRequest)

newUserName (Text) – Name of the new user (e.g., "Jane Doe").
newUserEmail (Text) – Email of the new user (also used as Username).
mirrorUserName (Text) – Identifier for the mirror user. (Name)

Outputs (CloneResponse)

mirrorUserId (Id) – Resolved Id of the mirror user.
newUserId (Id) – Id of the newly created user.
status (Text) – "SUCCESS" or "ERROR".
message (Text) – Friendly message, including error details if any.

## Example Flow Design
Use Case

“When a record is created (or a button is clicked), automatically create a new user with the same permissions as a given ‘template’ or mirror user.”

Flow Type

Recommended: Record-Triggered Flow on a custom “User Request” object, or

Screen Flow for admins to run manually.

High-Level Steps

Start – Record-triggered or Screen Flow.
Get Mirror User Identifier – From a field (e.g., Request__c.Mirror_User_Email__c).
Apex Action – “Clone User from Mirror”:

Map input fields:
newUserName ← e.g., Request__c.New_User_Name__c
newUserEmail ← e.g., Request__c.New_User_Email__c
mirrorUserName ← e.g., Request__c.Mirror_User_Identifier__c

Store Outputs – Map outputs to Flow variables:
var_mirrorUserId
var_newUserId
var_status
var_message

Decision – Check if var_status == 'SUCCESS'.
If Success:
Update request record with var_newUserId.
If Error:
Write var_message to an error field or surface on screen.
End.

## Notes and Best Practices

Bulk-safe: cloneUserInvocable accepts a list of requests and returns a list of responses. For most admin use cases, you’ll pass a single request, but the method is bulk-ready.
Error handling: Always check status and message in Flow to handle failures gracefully.
Governance: Consider adding:
Checks to ensure only system administrators can trigger the Flow.
Limits on how many users can be cloned in a single run for operational safety.

## Troubleshooting

If Flow returns ERROR with “Mirror user not found”:

Verify the mirrorUserName field matches a valid Name/Email/Username/Alias.
If user creation fails:
Check if the email/username is unique and valid.
Review the error message returned in message.
Ensure your running user has permissions to create users and assign permissions/licences.
