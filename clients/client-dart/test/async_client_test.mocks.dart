import 'dart:io';
// import 'package:channel_dart_client/src/connection_negotiator.dart';
import 'package:channel_dart_client/src/transport.dart';
import 'package:mockito/mockito.dart';

// class MockHttpClient extends Mock implements HttpClient {}
// class MockHttpHeaders extends Mock implements HttpHeaders {}
// class MockHttpClientResponse extends Mock implements HttpClientResponse {}
// class MockHttpClientRequest extends Mock implements HttpClientRequest {}
// class MockSocket extends Mock implements Socket {}
class MockWebSocket extends Mock implements WebSocket {}
// class MockConnectionNegotiator extends Mock implements ConnectionNegotiator{}
class MockTransport extends Mock implements Transport {}

// final mockHttpClient = MockHttpClient();
// final mockHttpRequest = MockHttpClientRequest();
// final mockHttpHeaders = MockHttpHeaders();
// final mockHttpResponse = MockHttpClientResponse();
// final mockSocket = MockSocket();
// final mockMockConnectionNegotiator = MockConnectionNegotiator();
final mockWebSocket = MockWebSocket();
final mockTransport = MockTransport();

void initMocks() {

  // final uri = Uri.http('localhost:8082', '/ext/socket', { 'channel' : 'ch_ref_0001' });
  // print(uri);
  // when(mockHttpClient.getUrl(Uri.http('localhost:8082', '/ext/socket', { 'channel' : 'ch_ref_0001' })))
  //   .thenAnswer((_) async => mockHttpRequest);
  
  // when(mockHttpRequest.headers).thenAnswer((_) => mockHttpHeaders);
  // when(mockHttpRequest.close()).thenAnswer((_) async => mockHttpResponse);

  // when(mockHttpResponse.statusCode).thenAnswer((_) => 101);
  // when(mockHttpResponse.reasonPhrase).thenAnswer((_) => 'Connection Upgrade');
  // when(mockHttpResponse.detachSocket()).thenAnswer((_) async => mockSocket);
  
  // when(mockMockConnectionNegotiator.connect(any, any, any)).thenAnswer((_) async => mockTransport);
  when(mockWebSocket.readyState).thenReturn(WebSocket.open);

}