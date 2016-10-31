/**
 * Executes a list of http requests asynchronously.
 * In general purpose, allows a large number of http callouts to be made.
 * In specific purpose, designed to make http callouts outside DML transactions.
 */
public class HttpRequestsBatchable implements Database.Batchable<Request>, Database.AllowsCallouts {

    private List<Request> requests;

    public HttpRequestsBatchable( List<Request> requests ) {
        this.requests = requests;
    }

    // ---------------------------------------------------------------------

    public Iterable<Request> start( Database.BatchableContext context ) {
        System.debug( 'HttpRequestsBatchable.start: ' + context );
        return this.requests;
    }

    public void execute( Database.BatchableContext context, List<Request> requests ) {

        System.debug( 'HttpRequestsBatchable.execute: ' + context );

        Http http = new Http();

        for ( Request request : requests ) {

            HttpRequest req = buildHttpRequest( request );

            System.debug( req );
            System.debug( req.getBody() );

            HttpResponse res = http.send( req );

            System.debug( res );
            System.debug( res.getBody() );

            if ( res.getStatusCode() >= 400 ) {
                throw new BatchableException( res.toString() );
            }

        }

    }

    public void finish( Database.BatchableContext context ) {
        System.debug( 'HttpRequestsBatchable.finish: ' + context );
    }

    // ---------------------------------------------------------------------

    /**
     * Creates a new HttpRequest instance based on values in the Request argument.
     */
    private HttpRequest buildHttpRequest( Request request ) {

        HttpRequest req = new HttpRequest();

        if ( String.isNotBlank( request.endpoint ) ) {
            req.setEndpoint( request.endpoint );
        }

        if ( String.isNotBlank( request.method) ) {
            req.setMethod( request.method );
        }

        if ( String.isNotBlank( request.body ) ) {
            req.setBody( request.body );
        }

        if ( request.timeout != null ) {
            req.setTimeout( request.timeout );
        }

        if ( request.compressed != null ) {
            req.setCompressed( request.compressed );
        }

        if ( request.headers != null ) {
            for ( String headerName : request.headers.keySet() ) {
                req.setHeader( headerName, request.headers.get( headerName ) );
            }
        }

        return req;
    }

    /**
     * Sadly the HttpRequest class is not serializable for async code (batchables, queueables, etc)
     * so had to create our own class for capturing the http request info.
     *
     * System.SerializationException: Not Serializable: com/salesforce/api/fast/List$$lcom/salesforce/api/System/HttpRequest$$r
     *
     * https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_restful_http_httprequest.htm
     */
    public class Request {

        public String endpoint { get; set; }
        public String method { get; set; }
        public String body { get; set; }
        public Integer timeout { get; set; }
        public Boolean compressed { get; set; }
        public Map<String, String> headers { get; set; }

        public Request() {
            this.method = 'GET';
            this.compressed = true;
            this.timeout = 10 * 1000; // 10 seconds in milliseconds
            this.headers = new Map<String, String>();
        }

    }

    public class BatchableException extends Exception {}

}