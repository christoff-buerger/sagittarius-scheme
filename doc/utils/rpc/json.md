[§2] (rpc json) - JSON RPC library {#lib.rpc.json}
-------------

###### [!Library] `(rpc json)` 

This library provides procedures handling 
[JSON RPC 2.0](http://www.jsonrpc.org/specification).

This library doesn't provide transport layer. To send request and receive
response, use [Http transport](#utils.rpc.transport.http).

This library uses [JSON parser library](#ported.json) and its
JSON representation.


Following piece of code describes how to use;

``````````scheme
(import (rnrs) (rpc json) (rpc transport http))

(define (json-rpc-send&request url method param)
  (let ((request (make-json-request method :param param)))
    (let-values (((status header response) (rpc-http-request url request)))
      ;; rpc-http-request unmarshalls only when HTTP status starts with "2"
      ;; for this example we don't check it.
      (json-response-result response))))

(json-rpc-send&request "http://localhost/json-rpc" "sample" "parameter")
;; -> result of method execution
``````````

###### [!Class] `<json-request>` 
###### [!Class] `<json-response>` 

These classes represents JSON RPC request and response respectively.

The class instance should be created by `make-json-request`,
`json-string->json-request` or `json-string->json-response`. Users
should not create an instance directly using `make`.


### [§3] Predicates

###### [!Function] `json-request?`  _object_
###### [!Function] `json-response?`  _object_

Returns #t if the given _object_ is an instance of 
`<json-request>` and `<json-response>` respectively.


### [§3] Constructors

###### [!Function] `make-json-request`  _method_ _:key_ _(params_ _'())_ _id_

Creates a JSON RPC request.

_method_ must be a symbol or string represents method name to be invoked.

The keyword argument _params_ is the `params` field of the JSON
RPC protocol.

The keyword argument _id_ is the `id` field of the JSON RPC protocol.
If this is not specified then a value generated by UUID v4 will be used.


###### [!Function] `json-string->json-request`  _json_
###### [!Function] `json-string->json-response`  _json_

Creates JSON RPC request and response from given JSON string _json_.


### [§3] Accessors

###### [!Function] `json-request-method`  _json-request_
###### [!Function] `json-request-params`  _json-request_
###### [!Function] `json-request-id`  _json-request_

Retrieves JSON RPC request's method, params and id respectively from given
json request object _json-request_.


###### [!Function] `json-response-result`  _json-response_
###### [!Function] `json-response-id`  _json-response_

Retrieves JSON RPC response's result and id respectively from given
json response object _json-response_.


### [§3] Converters

###### [!Function] `json-request->json-string`  _json-request_
###### [!Function] `json-response->json-string`  _json-response_

Converts given _json-request_ and _json-response_ to JSON string.


### [§3] Implemented methods

Following methods are currently used only in `(rpc http transport)`.
When we support other transport, this implementation may change.

#### [§4] Message methods

###### [!Method] `rpc-marshall-message`  _(message_ _<json-request>)_

Converts to given JSON RPC request object to UTF8 bytes.

###### [!Method] `rpc-unmarshall-message`  _(type_ _(eql_ _'json))_ _body_

Converts to given UTF8 bytes to JSON RPC response object.

#### [§4] Transport methods

###### [!Method] `rpc-http-content-type`  _(message_ _<json-request>)_

Returns `application/json` content type header value

###### [!Method] `rpc-http-response-type`  _(message_ _<json-request>)_

Returns `json` symbol.
