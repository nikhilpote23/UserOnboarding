/*@isTest
private class test_UserCloneService {
    private static Profile testProfile;
    private static UserRole testRole;

    static void setupData() {
        // Create test Profile and UserRole if not present
        testProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        if (testProfile == null) {
            testProfile = [SELECT Id FROM Profile LIMIT 1];
        }
        if ([SELECT COUNT() FROM UserRole] == 0) {
            testRole = null;
        } else {
            testRole = [SELECT Id FROM UserRole LIMIT 1];
        }
    }

    static User createMirrorUser(String name, String email) {
        User u = new User(
            FirstName = 'Mirror',
            LastName = 'User',
            Alias = 'mirruser',
            Email = email,
            Username = email,
            ProfileId = testProfile.Id,
            UserRoleId = testRole != null ? testRole.Id : null,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert u;
        return u;
    }

    @isTest
    static void testFindMirrorUserId() {
        setupData();
        User mirror = createMirrorUser('Mirror User', 'mirroruser@test.com');
        Test.startTest();
        Id foundId = UserCloneService.findMirrorUserId(mirror.Username);
        System.assertEquals(mirror.Id, foundId, 'Should find user by username');
        Test.stopTest();
    }

    @isTest
    static void testGetMirrorUserAssets() {
        setupData();
        User mirror = createMirrorUser('Mirror User', 'mirroruser2@test.com');
        Test.startTest();
        UserCloneService.MirrorUserAssets assets = UserCloneService.getMirrorUserAssets(mirror.Id);
        System.assertEquals(mirror.Id, assets.mirrorUserId);
        System.assertNotEquals(null, assets.permissionSetIds);
        System.assertNotEquals(null, assets.publicGroupIds);
        Test.stopTest();
    }

    @isTest
    static void testCloneMirrorUser() {
        setupData();
        User mirror = createMirrorUser('Mirror User', 'mirroruser3@test.com');
        String newUserName = 'Cloned User';
        String newUserEmail = 'cloneduser@test.com';
        Test.startTest();
        Id newUserId = UserCloneService.cloneMirrorUser(newUserName, newUserEmail, mirror.Username);
        Test.stopTest();
        User cloned = [SELECT Id, Username, Email, FirstName, LastName, ProfileId FROM User WHERE Id = :newUserId];
        System.assertEquals(newUserEmail, cloned.Username);
        System.assertEquals(newUserEmail, cloned.Email);
        System.assertEquals('Cloned', cloned.FirstName);
        System.assertEquals('User', cloned.LastName);
        System.assertEquals(mirror.ProfileId, cloned.ProfileId);
    }

    @isTest
    static void testCloneUserInvocable() {
        setupData();
        User mirror = createMirrorUser('Mirror User', 'mirroruser4@test.com');
        UserCloneService.CloneRequest req = new UserCloneService.CloneRequest();
        req.newUserName = 'Invocable User';
        req.newUserEmail = 'invocableuser@test.com';
        req.mirrorUserName = mirror.Username;
        List<UserCloneService.CloneRequest> requests = new List<UserCloneService.CloneRequest>{req};
        Test.startTest();
        List<UserCloneService.CloneResponse> responses = UserCloneService.cloneUserInvocable(requests);
        Test.stopTest();
        System.assertEquals(1, responses.size());
        System.assertEquals('SUCCESS', responses[0].status);
        System.assertNotEquals(null, responses[0].newUserId);
        System.assertEquals(mirror.Id, responses[0].mirrorUserId);
    }

    @isTest
    static void testCloneUserInvocableEmpty() {
        Test.startTest();
        List<UserCloneService.CloneResponse> responses = UserCloneService.cloneUserInvocable(new List<UserCloneService.CloneRequest>());
        Test.stopTest();
        System.assertEquals(1, responses.size());
        System.assertEquals('ERROR', responses[0].status);
    }

    @isTest
    static void testFindMirrorUserIdThrows() {
        Test.startTest();
        try {
            UserCloneService.findMirrorUserId('nonexistentuser@test.com');
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Mirror user not found'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetMirrorUserAssetsThrows() {
        Test.startTest();
        try {
            UserCloneService.getMirrorUserAssets(null);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('mirrorUserId is required'));
        }
        Test.stopTest();
    }

    @isTest
    static void testCloneMirrorUserThrows() {
        Test.startTest();
        try {
            UserCloneService.cloneMirrorUser('', 'email@test.com', 'mirroruser');
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('newUserName is required'));
        }
        Test.stopTest();
    }
}*/


@IsTest
private class UserCloneServiceTest {

    /**
     * Test setup: create a mirror user that will be used across tests.
     * Uses a standard profile to ensure portability across orgs.
     */
    @TestSetup
    static void setupData() {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        String suffix = String.valueOf(Datetime.now().getTime());

        User mirrorUser = new User(
            FirstName = 'Mirror',
            LastName = 'User',
            Alias = 'mirusr',
            Email = 'mirror.user.' + suffix + '@example.com',
            Username = 'mirror.user.' + suffix + '@example.com',
            CommunityNickname = 'mirroruser' + suffix,
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            TimeZoneSidKey = 'America/Los_Angeles',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert mirrorUser;
    }

    private static User getMirrorUser() {
        return [
            SELECT Id, FirstName, LastName, ProfileId, UserRoleId,
                   TimeZoneSidKey, LocaleSidKey, EmailEncodingKey, LanguageLocaleKey,
                   Email, Username
            FROM User
            WHERE Email LIKE 'mirror.user.%@example.com'
            LIMIT 1
        ];
    }

    @IsTest
    static void testFindMirrorUserId_ByEmail() {
        User mirrorUser = getMirrorUser();

        Test.startTest();
        Id foundId = UserCloneService.findMirrorUserId(mirrorUser.Email);
        Test.stopTest();

        System.assertEquals(mirrorUser.Id, foundId, 'Mirror user Id should match.');
    }

    @IsTest
    static void testFindMirrorUserId_NotFound() {
        Boolean threw = false;
    
        Test.startTest();
        try {
            UserCloneService.findMirrorUserId('nonexistent.user@example.com');
        } catch (Exception e) {
            threw = true;   // We only verify that an exception occurred
        }
        Test.stopTest();
    
        System.assert(threw, 'Expected an exception when mirror user is not found.');
    }
    
    @IsTest
    static void testGetMirrorUserAssets_NoAssets() {
        User mirrorUser = getMirrorUser();

        Test.startTest();
        UserCloneService.MirrorUserAssets assets =
            UserCloneService.getMirrorUserAssets(mirrorUser.Id);
        Test.stopTest();

        System.assertEquals(mirrorUser.Id, assets.mirrorUserId);
        System.assertNotEquals(null, assets.permissionSetIds);
        System.assertNotEquals(null, assets.publicGroupIds);
        System.assertNotEquals(null, assets.chatterGroupIds);
    }

    @IsTest
    static void testCloneMirrorUser_HappyPath() {
        User mirrorUser = getMirrorUser();
        String newEmail = 'cloned.user.' + String.valueOf(Datetime.now().getTime()) + '@example.com';

        Test.startTest();
        Id newUserId = UserCloneService.cloneMirrorUser('Cloned User', newEmail, mirrorUser.Email);
        Test.stopTest();

        System.assertNotEquals(null, newUserId, 'New user Id should be returned.');

        User cloned = [
            SELECT Id, Email, Username, Alias, ProfileId
            FROM User
            WHERE Id = :newUserId
        ];
        System.assertEquals(newEmail, cloned.Email, 'Email should match.');
        System.assertEquals(newEmail, cloned.Username, 'Username should match email.');
        System.assertNotEquals(null, cloned.Alias, 'Alias should be populated.');
        System.assertEquals(mirrorUser.ProfileId, cloned.ProfileId, 'ProfileId should match mirror user.');
    }

    @IsTest
    static void testCloneMirrorUser_ValidationErrors() {
        User mirrorUser = getMirrorUser();
        Boolean threwMissingName = false;
        Boolean threwMissingEmail = false;
        Boolean threwMissingMirror = false;

        Test.startTest();
        try {
            UserCloneService.cloneMirrorUser(null, 'x@example.com', mirrorUser.Email);
        } catch (AuraHandledException e) {
            threwMissingName = true;
        }

        try {
            UserCloneService.cloneMirrorUser('Name', null, mirrorUser.Email);
        } catch (AuraHandledException e) {
            threwMissingEmail = true;
        }

        try {
            UserCloneService.cloneMirrorUser('Name', 'x@example.com', null);
        } catch (AuraHandledException e) {
            threwMissingMirror = true;
        }
        Test.stopTest();

        System.assert(threwMissingName, 'Expected error when newUserName is null.');
        System.assert(threwMissingEmail, 'Expected error when newUserEmail is null.');
        System.assert(threwMissingMirror, 'Expected error when mirrorUserName is null.');
    }

    @IsTest
    static void testPostCloneUser_Success() {
        User mirrorUser = getMirrorUser();
        String newEmail = 'rest.user.' + String.valueOf(Datetime.now().getTime()) + '@example.com';

        // Prepare REST request/response context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/user-clone';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueOf(
            '{"newUserName":"REST User","newUserEmail":"' + newEmail +
            '","mirrorUserName":"' + mirrorUser.Email + '"}'
        );

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UserCloneService.postCloneUser();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'REST call should succeed.');

        String body = res.responseBody.toString();
        System.assert(body.contains('"status":"SUCCESS"'), 'Response should indicate SUCCESS.');
        System.assert(body.contains('"newUserId"'), 'Response should contain newUserId.');
    }

    @IsTest
    static void testPostCloneUser_EmptyBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/user-clone';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = null; // Empty body

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UserCloneService.postCloneUser();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 for empty body.');
        String body = res.responseBody.toString();
        System.assert(body.contains('"status":"ERROR"'), 'Response should indicate ERROR.');
    }

    @IsTest
    static void testCloneUserInvocable_SingleRequest() {
        User mirrorUser = getMirrorUser();
        String newEmail = 'flow.user.' + String.valueOf(Datetime.now().getTime()) + '@example.com';

        UserCloneService.CloneRequest req = new UserCloneService.CloneRequest();
        req.newUserName = 'Flow User';
        req.newUserEmail = newEmail;
        req.mirrorUserName = mirrorUser.Email;

        List<UserCloneService.CloneRequest> requests = new List<UserCloneService.CloneRequest>{ req };

        Test.startTest();
        List<UserCloneService.CloneResponse> responses =
            UserCloneService.cloneUserInvocable(requests);
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response.');
        UserCloneService.CloneResponse r = responses[0];

        System.assertEquals('SUCCESS', r.status, 'Status should be SUCCESS.');
        System.assertNotEquals(null, r.newUserId, 'New user Id should be populated.');
        System.assertEquals(mirrorUser.Id, r.mirrorUserId, 'Mirror user Id should match.');
    }

    @IsTest
    static void testCloneUserInvocable_NoRequests() {
        Test.startTest();
        List<UserCloneService.CloneResponse> responses =
            UserCloneService.cloneUserInvocable(new List<UserCloneService.CloneRequest>());
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one error response for empty input.');
        System.assertEquals('ERROR', responses[0].status);
        System.assert(responses[0].message.contains('No requests provided.'));
    }
}