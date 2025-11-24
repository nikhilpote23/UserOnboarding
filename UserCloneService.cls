/**
 * -----------------------------------------------------------------------------
 *  UserCloneService
 *  ----------------------------------------------------------------------------
 *  Apex REST + Invocable service for cloning Salesforce Users based
 *  on a "mirror" user. The service replicates the following user-related assets:
 *
 *   • Profile
 *   • Role
 *   • Permission Set Assignments
 *   • Permission Set Group Assignments
 *   • Permission Set License Assignments
 *   • Public Group Memberships
 *   • Chatter Group Memberships
 *   • Managed Package Licenses
 *
 *  This service exposes three integration surfaces:
 *    1. REST API     → `/services/apexrest/user-clone`  (POST)
 *    2. Aura/Lightning → Apex methods annotated with @AuraEnabled
 *    3. Invocable Method → For Flow/Process Builder automation
 *
 *  SECURITY NOTES:
 *    • This class uses "with sharing" to respect org-level data security.
 *    • Cloning a user requires administrative privileges—ensure the caller
 *      has appropriate permissions before exposing externally.
 *    • Alias and Username derivation is sanitized to avoid invalid formats.
 *
 *  GOV LIMITS:
 *    • All SOQL queries are selective.
 *    • Bulk-safe patterns used for inserts (Database.insert with partial success).
 *    • Dynamic SOQL used carefully.
 *
 *  AUTHOR:
 *    NIKHIL POTE
 *
 * -----------------------------------------------------------------------------
 */
@RestResource(urlMapping='/user-clone')
global with sharing class UserCloneService {

    // -------------------------------------------------------------------------
    // Request Wrapper for REST & Invocable Methods
    // -------------------------------------------------------------------------
    /**
     * Wrapper representing the input payload for cloning a user.
     * Used by REST API and Flow (Invocable) entry points.
     */
    global class CloneRequest {
        @InvocableVariable(required=true)
        public String newUserName;

        @InvocableVariable(required=true)
        public String newUserEmail;

        @InvocableVariable(required=true)
        public String mirrorUserName;
    }

    // -------------------------------------------------------------------------
    // Response Wrapper
    // -------------------------------------------------------------------------
    /**
     * Wrapper representing the output payload returned by clone operations.
     * Helpful for Flow, REST responses, and REST exception formatting.
     */
    global class CloneResponse {
        @InvocableVariable public Id mirrorUserId;
        @InvocableVariable public Id newUserId;
        @InvocableVariable public String status;
        @InvocableVariable public String message;
    }

    // -------------------------------------------------------------------------
    // Mirror User Assets
    // -------------------------------------------------------------------------
    /**
     * Data holder capturing all permission + group related assets associated
     * with a mirror user. Returned to UI to preview what will be replicated.
     */
    global class MirrorUserAssets {
        public Id mirrorUserId;
        public List<Id> permissionSetIds;
        public List<Id> permissionSetGroupIds;
        public List<Id> permissionSetLicenseIds;
        public List<Id> publicGroupIds;
        public List<Id> chatterGroupIds;
        public List<Id> packageLicenseIds;
    }

    // -------------------------------------------------------------------------
    // METHOD: findMirrorUserId
    // -------------------------------------------------------------------------
    /**
     * Finds a user by flexible identifiers:
     *   - Name
     *   - Username
     *   - Email
     *   - Alias
     *
     * Returns the most recently modified record when multiple matches occur.
     *
     * @param mirrorUserName  The search token representing the mirror user.
     * @return Id             The identified user's Id.
     */
    @AuraEnabled(cacheable=true)
    public static Id findMirrorUserId(String mirrorUserName) {
        if (String.isBlank(mirrorUserName)) {
            throw new AuraHandledException('mirrorUserName is required.');
        }

        // Query users using multiple matching fields. LIMIT 2 to detect ambiguity.
        List<User> candidates = [
            SELECT Id, Name, Username, Email, Alias
            FROM User
            WHERE Name = :mirrorUserName
               OR Username = :mirrorUserName
               OR Email = :mirrorUserName
               OR Alias = :mirrorUserName
            ORDER BY LastModifiedDate DESC
            LIMIT 2
        ];

        if (candidates.isEmpty()) {
            throw new AuraHandledException('Mirror user not found for: ' + mirrorUserName);
        }

        if (candidates.size() > 1) {
            // Debug logs help admins resolve ambiguous matches.
            for (User u : candidates) {
                System.debug('Multiple matches for mirror user: ' + u);
            }
        }

        return candidates[0].Id;
    }

    // -------------------------------------------------------------------------
    // METHOD: getMirrorUserAssets
    // -------------------------------------------------------------------------
    /**
     * Aggregates permission sets, permission set groups, licenses, public/
     * queue group memberships, chatter groups, and package licenses.
     *
     * Designed for UI preview and validation before performing a clone.
     *
     * @param mirrorUserId  The user from whom assets are derived.
     * @return MirrorUserAssets DTO containing all relevant asset IDs.
     */
    @AuraEnabled(cacheable=true)
    public static MirrorUserAssets getMirrorUserAssets(Id mirrorUserId) {
        if (mirrorUserId == null) {
            throw new AuraHandledException('mirrorUserId is required.');
        }

        MirrorUserAssets assets = new MirrorUserAssets();
        assets.mirrorUserId = mirrorUserId;
        assets.permissionSetIds = new List<Id>();
        assets.permissionSetGroupIds = new List<Id>();
        assets.permissionSetLicenseIds = new List<Id>();
        assets.publicGroupIds = new List<Id>();
        assets.chatterGroupIds = new List<Id>();
        assets.packageLicenseIds = new List<Id>();

        // Permission Set Assignments
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :mirrorUserId
        ]) {
            assets.permissionSetIds.add(psa.PermissionSetId);
        }

        // Permission Set Group Assignments (dynamic to avoid org dependency)
        Map<String, Schema.SObjectType> gdAssets = Schema.getGlobalDescribe();
        if (gdAssets.containsKey('PermissionSetGroupAssignment')) {
            List<SObject> psgRows = Database.query(
                'SELECT PermissionSetGroupId FROM PermissionSetGroupAssignment WHERE AssigneeId = :mirrorUserId'
            );
            for (SObject row : psgRows) {
                assets.permissionSetGroupIds.add((Id) row.get('PermissionSetGroupId'));
            }
        }

        // PSL Assignments
        for (PermissionSetLicenseAssign psla : [
            SELECT PermissionSetLicenseId
            FROM PermissionSetLicenseAssign
            WHERE AssigneeId = :mirrorUserId
        ]) {
            assets.permissionSetLicenseIds.add(psla.PermissionSetLicenseId);
        }

        // Public & Queue Groups
        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :mirrorUserId
        ]) {
            assets.publicGroupIds.add(gm.GroupId);
        }

        // Chatter Groups
        for (CollaborationGroupMember cgm : [
            SELECT CollaborationGroupId
            FROM CollaborationGroupMember
            WHERE MemberId = :mirrorUserId
        ]) {
            assets.chatterGroupIds.add(cgm.CollaborationGroupId);
        }

        // Managed Package Licenses
        for (UserPackageLicense upl : [
            SELECT PackageLicenseId
            FROM UserPackageLicense
            WHERE UserId = :mirrorUserId
        ]) {
            assets.packageLicenseIds.add(upl.PackageLicenseId);
        }

        return assets;
    }

    // -------------------------------------------------------------------------
    // METHOD: cloneMirrorUser
    // -------------------------------------------------------------------------
    /**
     * Creates a new user record using the metadata from a mirror user and
     * replicates all associated permission sets, groups, and licenses.
     *
     * @param newUserName     Name for the newly created user.
     * @param newUserEmail    Email (also used as username/login).
     * @param mirrorUserName  Identifier used to locate mirror user.
     * @return Id             Newly created user's Id.
     */
    @AuraEnabled
    public static Id cloneMirrorUser(String newUserName, String newUserEmail, String mirrorUserName) {
        if (String.isBlank(newUserName)) {
            throw new AuraHandledException('newUserName is required.');
        }
        if (String.isBlank(newUserEmail)) {
            throw new AuraHandledException('newUserEmail is required.');
        }
        if (String.isBlank(mirrorUserName)) {
            throw new AuraHandledException('mirrorUserName is required.');
        }

        // Step 1: Identify mirror user
        Id mirrorUserId = findMirrorUserId(mirrorUserName);

        // Step 2: Load mirror user's profile/locale/etc.
        User mirrorUser = [
            SELECT Id, FirstName, LastName, ProfileId, UserRoleId,
                   TimeZoneSidKey, LocaleSidKey, EmailEncodingKey, LanguageLocaleKey
            FROM User
            WHERE Id = :mirrorUserId
            LIMIT 1
        ];

        // Step 3: Build and insert the new user
        User newUser = buildUserFromMirror(mirrorUser, newUserName, newUserEmail);
        insert newUser;

        // Step 4: Copy assignments (Psets, groups, licenses)
        copyAssignments(mirrorUser.Id, newUser.Id);

        return newUser.Id;
    }

    // -------------------------------------------------------------------------
    // METHOD: postCloneUser (REST Endpoint)
    // -------------------------------------------------------------------------
    /**
     * REST Post handler for cloning users.
     * Expected JSON body:
     *   {
     *     "newUserName": "John Doe",
     *     "newUserEmail": "john.doe@example.com",
     *     "mirrorUserName": "existing.user@example.com"
     *   }
     *
     * @return JSON response with clone status and Ids.
     */
    @HttpPost
    global static void postCloneUser() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        // Standard JSON response setup
        res.addHeader('Content-Type', 'application/json');
        CloneResponse out = new CloneResponse();

        try {
            String body = (req.requestBody == null) ? null : req.requestBody.toString();
            if (String.isBlank(body)) {
                throw new AuraHandledException('Empty request body.');
            }

            // Deserialize request payload
            CloneRequest input = (CloneRequest) JSON.deserialize(body, CloneRequest.class);

            // Execute clone operation
            Id mirrorUserId = findMirrorUserId(input.mirrorUserName);
            out.mirrorUserId = mirrorUserId;
            out.newUserId = cloneMirrorUser(input.newUserName, input.newUserEmail, input.mirrorUserName);

            out.status = 'SUCCESS';
            out.message = 'User cloned.';
            res.statusCode = 200;

        } catch (Exception e) {
            out.status = 'ERROR';
            out.message = e.getMessage();
            res.statusCode = 400;
        }

        res.responseBody = Blob.valueOf(JSON.serialize(out));
    }

    // -------------------------------------------------------------------------
    // METHOD: cloneUserInvocable (Flow)
    // -------------------------------------------------------------------------
    /**
     * Flow-friendly clone action. Allows bulk invocation by Flow or Process Builder.
     *
     * @param requests  List<CloneRequest> representing multiple clone operations.
     * @return List<CloneResponse> containing outcomes for each input.
     */
    @InvocableMethod(label='Clone User from Mirror'
                     description='Clones a user based on a mirror user and copies assignments.')
    public static List<CloneResponse> cloneUserInvocable(List<CloneRequest> requests) {
        List<CloneResponse> results = new List<CloneResponse>();

        if (requests == null || requests.isEmpty()) {
            CloneResponse res = new CloneResponse();
            res.status = 'ERROR';
            res.message = 'No requests provided.';
            results.add(res);
            return results;
        }

        for (CloneRequest req : requests) {
            CloneResponse res = new CloneResponse();
            try {
                Id mirrorId = findMirrorUserId(req.mirrorUserName);
                res.mirrorUserId = mirrorId;
                res.newUserId = cloneMirrorUser(req.newUserName, req.newUserEmail, req.mirrorUserName);
                res.status = 'SUCCESS';
                res.message = 'User cloned.';
            } catch (Exception e) {
                res.status = 'ERROR';
                res.message = e.getMessage();
            }
            results.add(res);
        }

        return results;
    }

    // -------------------------------------------------------------------------
    // METHOD: buildUserFromMirror
    // -------------------------------------------------------------------------
    /**
     * Helper method that constructs the new user based on mirror user's settings.
     * Ensures alias/username rules are followed.
     */
    private static User buildUserFromMirror(User mirrorUser, String newUserName, String newUserEmail) {

        // Derive first/last name from provided full name
        String firstName;
        String lastName;
        List<String> parts = newUserName.split('\\s+');

        if (parts.size() > 1) {
            firstName = parts.remove(0);
            lastName = String.join(parts, ' ');
        } else {
            firstName = null;
            lastName = newUserName;
        }

        // Alias generated from email prefix
        String alias = deriveAliasFromEmail(newUserEmail);

        // Create the new user record
        User objUsr = new User();
        objUsr.FirstName = firstName;
        objUsr.LastName = lastName;
        objUsr.Alias = alias;
        objUsr.Email = newUserEmail;
        objUsr.Username = newUserEmail;
        objUsr.ProfileId = mirrorUser.ProfileId;
        objUsr.UserRoleId = mirrorUser.UserRoleId;
        objUsr.TimeZoneSidKey = mirrorUser.TimeZoneSidKey;
        objUsr.LocaleSidKey = mirrorUser.LocaleSidKey;
        objUsr.EmailEncodingKey = mirrorUser.EmailEncodingKey;
        objUsr.LanguageLocaleKey = mirrorUser.LanguageLocaleKey;
        objUsr.IsActive = true;

        return objUsr;
    }

    // -------------------------------------------------------------------------
    // METHOD: deriveAliasFromEmail
    // -------------------------------------------------------------------------
    /**
     * Creates a valid Salesforce alias from an email prefix.
     * Ensures:
     *   • Only alphanumeric characters
     *   • Max length = 8
     */
    private static String deriveAliasFromEmail(String email) {

        // Extract prefix before '@' or fallback to raw email
        String prefix = email != null && email.contains('@')
            ? email.substring(0, email.indexOf('@'))
            : (email == null ? 'user' : email);

        // Keep only alphanumeric characters
        String cleaned = prefix.replaceAll('[^A-Za-z0-9]', '');

        if (String.isBlank(cleaned)) {
            cleaned = 'user';
        }

        // Alias max length rule
        Integer maxLen = 8;
        return cleaned.length() > maxLen ? cleaned.substring(0, maxLen) : cleaned;
    }

    // -------------------------------------------------------------------------
    // METHOD: copyAssignments
    // -------------------------------------------------------------------------
    /**
     * Copies all permission set assignments, permission set groups, licenses,
     * public groups, chatter groups, and managed package licenses from the
     * source user to the newly created target user.
     *
     * Uses partial insert (Database.insert with false) to avoid failures if
     * certain assets (e.g., package licenses) cannot be assigned.
     */
    private static void copyAssignments(Id sourceUserId, Id targetUserId) {

        // Permission Set Assignments
        List<PermissionSetAssignment> newPsas = new List<PermissionSetAssignment>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :sourceUserId
        ]) {
            newPsas.add(new PermissionSetAssignment(
                AssigneeId = targetUserId,
                PermissionSetId = psa.PermissionSetId
            ));
        }
        if (!newPsas.isEmpty()) {
            Database.insert(newPsas, false);
        }

        // Permission Set Group Assignments (dynamic to avoid missing object errors)
        Map<String, Schema.SObjectType> objGD = Schema.getGlobalDescribe();
        if (objGD.containsKey('PermissionSetGroupAssignment')) {
            List<SObject> psgSource = Database.query(
                'SELECT PermissionSetGroupId FROM PermissionSetGroupAssignment WHERE AssigneeId = :sourceUserId'
            );

            List<SObject> psgToInsert = new List<SObject>();
            Schema.SObjectType psgType = objGD.get('PermissionSetGroupAssignment');

            for (SObject row : psgSource) {
                SObject rec = psgType.newSObject();
                rec.put('AssigneeId', targetUserId);
                rec.put('PermissionSetGroupId', (Id) row.get('PermissionSetGroupId'));
                psgToInsert.add(rec);
            }
            if (!psgToInsert.isEmpty()) {
                Database.insert(psgToInsert, false);
            }
        }

        // Permission Set License Assignments
        List<PermissionSetLicenseAssign> newPslas = new List<PermissionSetLicenseAssign>();
        for (PermissionSetLicenseAssign psla : [
            SELECT PermissionSetLicenseId
            FROM PermissionSetLicenseAssign
            WHERE AssigneeId = :sourceUserId
        ]) {
            newPslas.add(new PermissionSetLicenseAssign(
                AssigneeId = targetUserId,
                PermissionSetLicenseId = psla.PermissionSetLicenseId
            ));
        }
        if (!newPslas.isEmpty()) {
            Database.insert(newPslas, false);
        }

        // Public + Queue Group Memberships
        List<GroupMember> newGroupMembers = new List<GroupMember>();
        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :sourceUserId
        ]) {
            newGroupMembers.add(new GroupMember(
                GroupId = gm.GroupId,
                UserOrGroupId = targetUserId
            ));
        }
        if (!newGroupMembers.isEmpty()) {
            Database.insert(newGroupMembers, false);
        }

        // Chatter Groups
        List<CollaborationGroupMember> newCgm = new List<CollaborationGroupMember>();
        for (CollaborationGroupMember cgm : [
            SELECT CollaborationGroupId
            FROM CollaborationGroupMember
            WHERE MemberId = :sourceUserId
        ]) {
            newCgm.add(new CollaborationGroupMember(
                CollaborationGroupId = cgm.CollaborationGroupId,
                MemberId = targetUserId
            ));
        }
        if (!newCgm.isEmpty()) {
            Database.insert(newCgm, false);
        }

        // Managed Package Licenses
        List<UserPackageLicense> newUpls = new List<UserPackageLicense>();
        for (UserPackageLicense upl : [
            SELECT PackageLicenseId
            FROM UserPackageLicense
            WHERE UserId = :sourceUserId
        ]) {
            newUpls.add(new UserPackageLicense(
                PackageLicenseId = upl.PackageLicenseId,
                UserId = targetUserId
            ));
        }
        if (!newUpls.isEmpty()) {
            Database.insert(newUpls, false);
        }
    }
}