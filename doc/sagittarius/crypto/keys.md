[§3] Key library - (sagittarius crypto keys) {#sagittarius.crypto.keys}
------------------------------------------------------

The key library provides key operations for both symmetric and asymmetric
keys.

###### [!Library] `(sagittarius crypto keys)`

The key library, this library exports the procedures listed below sections.

### [§4] Key type

Sagittarius crypto library uses hierachial key structure. The hierarchy of
the key type is below.

```
                 +--------------+
                 | <crypto-key> |
                 +------+-------+
                        |
         +--------------+-------------+
         |                            |
+--------+--------+          +--------+---------+
| <symmetric-key> |          | <asymmetric-key> |
+-----------------+          +--------+---------+
                                      |
                             +--------+--------+
                             |                 |
                     +-------+------+  +-------+------+
                     | <public-key> |  | <private-key |
                     +--------------+  +--------------+
```

###### [!Function] `crypto-key?` _obj_

Returns `#t` if the given _obj_ is an instance of `<crypto-key>`,
otherwise `#f`.

###### [!Function] `symmetric-key?` _obj_

Returns `#t` if the given _obj_ is an instance of `<symmetric-key>`,
otherwise `#f`.

###### [!Function] `asymmetric-key?` _obj_

Returns `#t` if the given _obj_ is an instance of `<asymmetric-key>`,
otherwise `#f`.

###### [!Function] `public-key?` _obj_

Returns `#t` if the given _obj_ is an instance of `<public-key>`,
otherwise `#f`.

###### [!Function] `private-key?` _obj_

Returns `#t` if the given _obj_ is an instance of `<private-key>`,
otherwise `#f`.

### [§4] Symmetric key operations

###### [!Function] `make-symmetric-key` (_bv_ `bytevector?`)

Creates a symmetric key of the value of _bv_.  
The key can be used for any of the symmetric ciphers supported by
Sagittarius, however it is users' responsibility to align the key
size. If you want to make sure the _bv_ has the right key size,
consier using `generate-symmetric-key` method.

###### [!Function] `symmetric-key-value` (_key_ `symmetric-key?`)

Retrieves the raw key value of the given _key_.

###### [!Method] `generate-symmetric-key` `<block-cipher-descriptor>`
###### [!Method] `generate-symmetric-key` `<block-cipher-descriptor>` `<random-generator>`

Generates a symmetric key suitable for the given block cipher scheme, 
randomly.

###### [!Method] `generate-symmetric-key` `<block-cipher-descriptor>` `<bytevector>`

Creates a symmetric from the bytevector, this method checks the
key size if it's appropriate for the given cipher or not.

###### [!Function] `make-rfc3394-key-wrap` (_scheme_ `block-cipher-descriptor?`) (_key_ `symmetric-key?`) :key _iv_

Creates a key wrap procedure using given _scheme_ and _key_. The optional
keyword parameter _iv_ is used as an initial vector if provided.

###### [!Function] `make-aes-key-wrap` (_key_ `symmetric-key?`) _opts_ _..._

Creates an AES key wrap procedure.

###### [!Function] `make-camellia-key-wrap` (_key_ `symmetric-key?`) _opts_ _..._

Creates an Camellia key wrap procedure.

###### [!Function] `make-rfc3394-key-unwrap` (_scheme_ `block-cipher-descriptor?`) (_key_ `symmetric-key?`) :key _iv_

Creates a key unwrap procedure using given _scheme_ and _key_. The optional
keyword parameter _iv_ is used as an initial vector if provided.

###### [!Function] `make-aes-key-unwrap` (_key_ `symmetric-key?`) _opts_ _..._

Creates an AES key unwrap procedure.

###### [!Function] `make-camellia-key-unwrap` (_key_ `symmetric-key?`) _opts_ _..._

Creates an Camellia key unwrap procedure.


### [§4] Asymmetric key operations

###### [!Function] `key-pair?` _obj_

Returns `#t` if the given _obj_ is a key pair, otherwise `#f`.

###### [!Function] `key-pair-private` (_kp_ `key-pair?`)

Returns the private key of the given _kp_.

###### [!Function] `key-pair-public`

Returns the public key of the given _kp_.

###### [!Method] `generate-key-pair` _scheme_ _opts_ _..._

Generates a key pair of the given _scheme_. Followings are the supported
schemes:

###### [!Key scheme] `*key:rsa`
###### [!Key scheme] `*key:dsa`
###### [!Key scheme] `*key:ecdsa`
###### [!Key scheme] `*key:ed25519`
###### [!Key scheme] `*key:ed448`
###### [!Key scheme] `*key:x25519`
###### [!Key scheme] `*key:x448`

Those are RSA, DSA, ECDSA, Ed5519, Ed448, X25519 and X448 respectively.  
For convenience `*scheme:rsa` has the same effect as `*key:rsa`.

###### [!Function] `generate-public-key` _scheme_ _opts_ ...
###### [!Function] `generate-private-key` _scheme_ _opts_ ...

###### [!Function] `import-public-key`
###### [!Function] `import-private-key`

###### [!Function] `export-public-key`
###### [!Function] `export-private-key`

###### [!Function] `oid->key-operation`
###### [!Function] `key->oid`

###### [!Function] `public-key-format`
###### [!Function] `*public-key-formats*`
###### [!Function] `public-key-format?`
###### [!Function] `calculate-key-agreement`
###### [!Function] `private-key-format`
###### [!Function] `*private-key-formats*`
###### [!Function] `private-key-format?`