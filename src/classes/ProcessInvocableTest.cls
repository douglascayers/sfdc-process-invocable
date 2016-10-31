@isTest
private class ProcessInvocableTest {

    @isTest
    static void test_invocable() {

        ProcessInvocable.ProcessRequest request = new ProcessInvocable.ProcessRequest();
        request.processName = 'Test_Process';
        request.recordId = UserInfo.getUserId();
        request.recordIds = new List<ID>{ UserInfo.getUserId() };
        request.apiVersion = 38.0;
        request.namedCredential = 'Test_Named_Credential';

        List<ProcessInvocable.ProcessRequest> requests = new List<ProcessInvocable.ProcessRequest>{ request };

        Test.setMock( HttpCalloutMock.class, new SimpleHttpCalloutMock() );

        Test.startTest();

        ProcessInvocable.invokeProcess( requests );

        Test.stopTest();

    }

}