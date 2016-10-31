/**
 * An adapter class to allow invocable Processes to be called from Flows.
 *
 * In Winter '17 release, invocable processes were introduced:
 * https://releasenotes.docs.salesforce.com/en-us/winter17/release-notes/rn_forcecom_process_in_process.htm
 *
 * So at the time the ways Flows and Processes could be invoked was:
 *      - Processes invoke Processes
 *      - Processes invoke Flows
 *      - Flows invoke Flows
 *      - ... but Flows could not invoke Processes ...
 *
 * Also in Winter '17 release, the ability to invoke Processes is available in
 * the Actions REST API. This code exposes to Flows the ability to invoke Processes
 * by way of invocable apex that makes the http request to REST API.
 *
 * The benefit is that Flows can on-demand call reusable Processes!
 * However, since Salesforce REST API requires OAuth authentication, we have to use
 * Named Credentials when making the http request, so there is some extra
 * setup by the admin and potentially by the end-users before this solution can be used.
 */
public class ProcessInvocable {

    // defines the input parameters of this flow element in the canvas designer
    public class ProcessRequest {

        @InvocableVariable(
            label = 'Process Name'
            description = 'Unique API Name of the Process or Flow to invoke.'
            required = true
        )
        public String processName;

        @InvocableVariable(
            label = 'Record ID'
            description = 'Salesforce ID of the record that the Process or Flow will execute on. Use "Record IDs" collection input parameter when able to be bulk-friendly. Either "Record ID" or "Record IDs" input parameter must be specified.'
            required = false
        )
        public ID recordId;

        @InvocableVariable(
            label = 'Record IDs'
            description = '(Recommended) Salesforce IDs of the records that the Process or Flow will execute on. Must all be the same object type. Either "Record ID" or "Record IDs" input parameter must be specified.'
            required = false
        )
        public List<ID> recordIds;

        @InvocableVariable(
            label = 'Named Credential'
            description = 'The Named Credential to use to authenticate to Salesforce REST API when making http callouts to invoke the Process or Flow.'
            required = true
        )
        public String namedCredential;

        @InvocableVariable(
            label = 'API Version'
            description = 'The REST API version to use when calling Actions API to invoke the Process (38.0 and above) or Flow (32.0 and above).'
            required = true
        )
        public Double apiVersion;

    }

    @InvocableMethod(
        label = 'Invoke Process'
    )
    public static void invokeProcess( List<ProcessRequest> requests ) {

        // since Actions API can invoke a Process or Flow passing in multiple record ids
        // then we will batch up the requests to make fewer http requests, hopefully
        // yielding faster performance and staying within governor limits
        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
        Map<String, List<ProcessRequest>> requestsMap = new Map<String, List<ProcessRequest>>();

        // build map of process name + api version to list of requests all calling the same action
        for ( ProcessRequest request : requests ) {

            String key = request.namedCredential + request.processName + request.apiVersion;

            List<ProcessRequest> processRequests = requestsMap.get( key );

            if ( processRequests == null ) {
                processRequests = new List<ProcessRequest>();
            }

            processRequests.add( request );

            requestsMap.put( key, processRequests );

        }

        List<HttpRequestsBatchable.Request> httpRequests = new List<HttpRequestsBatchable.Request>();

        for ( String key : requestsMap.keySet() ) {

            String processName = null;
            String namedCredential = null;
            Double apiVersion = null;

            List<Map<String, Object>> inputs = new List<Map<String, Object>>();

            for ( ProcessRequest request : requestsMap.get( key ) ) {

                // these three variables defined the unique map key
                // so each request we're iterating through will have the same values,
                // we just grab the values from the first element in the list
                // so we can reference them when building up the endpoint url
                if ( processName     == null ) processName     = request.processName;
                if ( namedCredential == null ) namedCredential = request.namedCredential;
                if ( apiVersion      == null ) apiVersion      = request.apiVersion;

                if ( String.isBlank( request.recordId ) && request.recordIds == null ) {
                    throw new ProcessException( 'Missing required input parameter. Please specify either "Record IDs" or "Record ID"' );
                }

                // Actions API can invoke processes and flows passing in multiple record ids
                // so we'll add each record id from the process request here
                // https://developer.salesforce.com/docs/atlas.en-us.api_action.meta/api_action/actions_intro_invoking.htm
                if ( request.recordIds != null ) {
                    for ( ID recordId : request.recordIds ) {
                        inputs.add( new Map<String, Object>{
                            'SObjectId' => recordId
                        });
                    }
                }

                if ( String.isNotBlank( request.recordId ) ) {
                    inputs.add( new Map<String, Object>{
                        'SObjectId' => request.recordId
                    });
                }

            }

            // Sadly the HttpRequest class is not serializable for async code (batchables, queueables, etc)
            // so had to create our own class for capturing the http request info.
            // System.SerializationException: Not Serializable: com/salesforce/api/fast/List$$lcom/salesforce/api/System/HttpRequest$$r
            // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_restful_http_httprequest.htm
            HttpRequestsBatchable.Request req = new HttpRequestsBatchable.Request();

            // Salesforce REST API requires OAuth authentication so we have to use Named Credential here
            // even if we hard code the authorization header with UserInfo.getSessionId(), when the http callout
            // is made to the REST API we get error that the session id is invalid for REST API usage.
            // https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/intro_understanding_authentication.htm
            req.endpoint = 'callout:' + namedCredential + '/services/data/v' + apiVersion + '/actions/custom/flow/' + processName;
            req.method = 'POST';
            req.body = JSON.serialize( new Map<String, Object>{ 'inputs' => inputs } );
            req.compressed = true;

            Map<String, String> headers = new Map<String, String>();
            headers.put( 'Content-Type', 'application/json; charset=UTF-8' );
            headers.put( 'Accept', 'application/json' );

            req.headers = headers;

            httpRequests.add( req );

        }

        // to make callouts we must do so asynchronously otherwise will get error
        // about uncommitted work in this transaction if DML changes occurred
        //
        // we set batch size to max callout limits allowed per transaction, although
        // since we're making apex callout back to Salesforce API there might not be a limit...
        // https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/salesforce_app_limits_platform_api.htm
        Database.executeBatch( new HttpRequestsBatchable( httpRequests ), Limits.getLimitCallouts() );

    }

    public class ProcessException extends Exception {}

}