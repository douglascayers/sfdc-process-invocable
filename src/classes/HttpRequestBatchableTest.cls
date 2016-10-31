@isTest
private class HttpRequestBatchableTest {

    @isTest
    static void test_batch() {

        HttpRequestsBatchable.Request request = new HttpRequestsBatchable.Request();
        request.endpoint = URL.getSalesforceBaseURL().toExternalForm();
        request.method = 'POST';
        request.body = 'hello world';
        request.compressed = true;
        request.timeout = 10000;
        request.headers = new Map<String, String>{
            'Header' => 'Value'
        };

        List<HttpRequestsBatchable.Request> requests = new List<HttpRequestsBatchable.Request>{ request };

        Test.setMock( HttpCalloutMock.class, new SimpleHttpCalloutMock() );

        Test.startTest();

        Database.executeBatch( new HttpRequestsBatchable( requests ) );

        Test.stopTest();

    }

}