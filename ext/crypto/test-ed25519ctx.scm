(define ed25519ctx-signer (make-eddsa-signer ed25519ctx-scheme))
(define ed25519ctx-verifier (make-eddsa-verifier ed25519ctx-scheme))

(define test-ed25519ctx
  (make-test-eddsa Ed25519ctx ed25519ctx-signer ed25519ctx-verifier))

(test-ed25519ctx
 #x0305334e381af78f141cb666f6199f57bc3495335a256a95bd2a55bf546663f6
 #xdfc9425e4f968f7f0c29f0259cf5f9aed6851c2bb4ad8bfb860cfee0ab248292
 (integer->bytevector #xf726936d19c800494e3fdaff20b276a8)
 #x55a4cc2f70a54e04288c5f4cd1e45a7bb520b36292911876cada7323198dd87a8b36950b95130022907a7fb7c4e9b2d5f6cca685a587b4b21f4b888e4e7edb0d
 :context (integer->bytevector #x666f6f))

(test-ed25519ctx
 #x0305334e381af78f141cb666f6199f57bc3495335a256a95bd2a55bf546663f6
 #xdfc9425e4f968f7f0c29f0259cf5f9aed6851c2bb4ad8bfb860cfee0ab248292
 (integer->bytevector #xf726936d19c800494e3fdaff20b276a8)
 #xfc60d5872fc46b3aa69f8b5b4351d5808f92bcc044606db097abab6dbcb1aee3216c48e8b3b66431b5b186d1d28f8ee15a5ca2df6668346291c2043d4eb3e90d
 :context (integer->bytevector #x626172))

(test-ed25519ctx
 #x0305334e381af78f141cb666f6199f57bc3495335a256a95bd2a55bf546663f6
 #xdfc9425e4f968f7f0c29f0259cf5f9aed6851c2bb4ad8bfb860cfee0ab248292
 (integer->bytevector #x508e9e6882b979fea900f62adceaca35)
 #x8b70c1cc8310e1de20ac53ce28ae6e7207f33c3295e03bb5c0732a1d20dc64908922a8b052cf99b7c4fe107a5abb5b2c4085ae75890d02df26269d8945f84b0b
 :context (integer->bytevector #x666f6f))

(test-ed25519ctx
 #xab9c2853ce297ddab85c993b3ae14bcad39b2c682beabc27d6d4eb20711d6560
 #x0f1d1274943b91415889152e893d80e93275a1fc0b65fd71b4b0dda10ad7d772
 (integer->bytevector #xf726936d19c800494e3fdaff20b276a8)
 #x21655b5f1aa965996b3f97b3c849eafba922a0a62992f73b3d1b73106a84ad85e9b86a7b6005ea868337ff2d20a7f5fbd4cd10b0be49a68da2b2e0dc0ad8960f
 :context (integer->bytevector #x666f6f))
