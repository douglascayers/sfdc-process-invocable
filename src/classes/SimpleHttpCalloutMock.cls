@isTest
public class SimpleHttpCalloutMock implements HttpCalloutMock {

    public HttpResponse respond( HttpRequest request ) {

        HttpResponse response = new HttpResponse();

        response.setStatusCode( 200 );
        response.setStatus( 'OK' );

        return response;
    }

}