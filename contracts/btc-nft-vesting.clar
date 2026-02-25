(define-non-fungible-token vested-nft uint)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-OWNER (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-CLAIMED (err u102))
(define-constant ERR-VESTING-NOT-MET (err u103))
(define-constant ERR-INVALID-PARAMS (err u104))
(define-constant ERR-NOT-AUTHORIZED (err u105))
(define-constant ERR-ALREADY-EXISTS (err u106))
(define-constant ERR-ORACLE-ONLY (err u107))
(define-constant ERR-PAUSED (err u108))

(define-data-var next-token-id uint u1)
(define-data-var oracle-principal principal CONTRACT-OWNER)
(define-data-var confirmed-btc-height uint u0)
(define-data-var contract-paused bool false)
(define-data-var total-vested uint u0)
(define-data-var total-claimed uint u0)

(define-map vesting-schedules
    uint
    {
        owner: principal,
        recipient: principal,
        btc-unlock-height: uint,
        metadata-uri: (string-ascii 256),
        claimed: bool,
        created-at-stx-height: uint,
        token-amount: uint
    }
)

(define-map recipient-tokens principal (list 100 uint))
(define-map owner-tokens principal (list 100 uint))
(define-map token-exists uint bool)

(define-read-only (get-owner)
    (ok CONTRACT-OWNER)
)

(define-read-only (get-oracle)
    (ok (var-get oracle-principal))
)

(define-read-only (get-confirmed-btc-height)
    (ok (var-get confirmed-btc-height))
)

(define-read-only (get-total-vested)
    (ok (var-get total-vested))
)

(define-read-only (get-total-claimed)
    (ok (var-get total-claimed))
)

(define-read-only (is-paused)
    (ok (var-get contract-paused))
)

(define-read-only (get-vesting-schedule (token-id uint))
    (ok (map-get? vesting-schedules token-id))
)

(define-read-only (get-recipient-tokens (recipient principal))
    (ok (default-to (list) (map-get? recipient-tokens recipient)))
)

(define-read-only (get-owner-tokens (owner principal))
    (ok (default-to (list) (map-get? owner-tokens owner)))
)

(define-read-only (is-claimable (token-id uint))
    (let (
        (schedule (unwrap! (map-get? vesting-schedules token-id) (err false)))
        (btc-height (var-get confirmed-btc-height))
    )
    (ok (and
        (not (get claimed schedule))
        (>= btc-height (get btc-unlock-height schedule))
    )))
)

(define-read-only (get-nft-owner (token-id uint))
    (ok (nft-get-owner? vested-nft token-id))
)

(define-public (set-oracle (new-oracle principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
        (var-set oracle-principal new-oracle)
        (print { event: "oracle-updated", new-oracle: new-oracle })
        (ok true)
    )
)

(define-public (set-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
        (var-set contract-paused paused)
        (print { event: "pause-state-changed", paused: paused })
        (ok true)
    )
)

(define-public (update-btc-height (new-height uint))
    (begin
        (asserts! (is-eq tx-sender (var-get oracle-principal)) ERR-ORACLE-ONLY)
        (asserts! (> new-height (var-get confirmed-btc-height)) ERR-INVALID-PARAMS)
        (var-set confirmed-btc-height new-height)
        (print { event: "btc-height-updated", height: new-height })
        (ok true)
    )
)

(define-public (create-vesting
    (recipient principal)
    (btc-unlock-height uint)
    (metadata-uri (string-ascii 256))
    (token-amount uint)
)
    (let (
        (token-id (var-get next-token-id))
        (caller tx-sender)
    )
    (asserts! (not (var-get contract-paused)) ERR-PAUSED)
    (asserts! (> btc-unlock-height (var-get confirmed-btc-height)) ERR-INVALID-PARAMS)
    (asserts! (> token-amount u0) ERR-INVALID-PARAMS)
    (asserts! (> (len metadata-uri) u0) ERR-INVALID-PARAMS)

    (try! (nft-mint? vested-nft token-id (as-contract tx-sender)))

    (map-set vesting-schedules token-id {
        owner: caller,
        recipient: recipient,
        btc-unlock-height: btc-unlock-height,
        metadata-uri: metadata-uri,
        claimed: false,
        created-at-stx-height: stacks-block-height,
        token-amount: token-amount
    })

    (map-set token-exists token-id true)

    (map-set owner-tokens caller
        (unwrap! (as-max-len?
            (append (default-to (list) (map-get? owner-tokens caller)) token-id)
            u100)
        ERR-INVALID-PARAMS)
    )

    (map-set recipient-tokens recipient
        (unwrap! (as-max-len?
            (append (default-to (list) (map-get? recipient-tokens recipient)) token-id)
            u100)
        ERR-INVALID-PARAMS)
    )

    (var-set next-token-id (+ token-id u1))
    (var-set total-vested (+ (var-get total-vested) u1))

    (print {
        event: "vesting-created",
        token-id: token-id,
        owner: caller,
        recipient: recipient,
        btc-unlock-height: btc-unlock-height,
        token-amount: token-amount
    })
    (ok token-id))
)

(define-public (claim-vested-nft (token-id uint))
    (let (
        (schedule (unwrap! (map-get? vesting-schedules token-id) ERR-NOT-FOUND))
        (caller tx-sender)
        (btc-height (var-get confirmed-btc-height))
    )
    (asserts! (not (var-get contract-paused)) ERR-PAUSED)
    (asserts! (is-eq caller (get recipient schedule)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get claimed schedule)) ERR-ALREADY-CLAIMED)
    (asserts! (>= btc-height (get btc-unlock-height schedule)) ERR-VESTING-NOT-MET)

    (try! (as-contract (nft-transfer? vested-nft token-id tx-sender caller)))

    (map-set vesting-schedules token-id
        (merge schedule { claimed: true })
    )

    (var-set total-claimed (+ (var-get total-claimed) u1))

    (print {
        event: "nft-claimed",
        token-id: token-id,
        recipient: caller,
        btc-height-at-claim: btc-height
    })
    (ok true))
)

(define-public (revoke-vesting (token-id uint))
    (let (
        (schedule (unwrap! (map-get? vesting-schedules token-id) ERR-NOT-FOUND))
        (caller tx-sender)
    )
    (asserts! (is-eq caller (get owner schedule)) ERR-NOT-OWNER)
    (asserts! (not (get claimed schedule)) ERR-ALREADY-CLAIMED)
    (asserts! (< (var-get confirmed-btc-height) (get btc-unlock-height schedule)) ERR-VESTING-NOT-MET)

    (try! (as-contract (nft-transfer? vested-nft token-id tx-sender caller)))

    (map-delete vesting-schedules token-id)
    (map-delete token-exists token-id)

    (var-set total-vested (- (var-get total-vested) u1))

    (print {
        event: "vesting-revoked",
        token-id: token-id,
        owner: caller
    })
    (ok true))
)

(define-public (update-metadata-uri (token-id uint) (new-uri (string-ascii 256)))
    (let (
        (schedule (unwrap! (map-get? vesting-schedules token-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner schedule)) ERR-NOT-OWNER)
    (asserts! (not (get claimed schedule)) ERR-ALREADY-CLAIMED)
    (asserts! (> (len new-uri) u0) ERR-INVALID-PARAMS)

    (map-set vesting-schedules token-id
        (merge schedule { metadata-uri: new-uri })
    )
    (print { event: "metadata-updated", token-id: token-id, new-uri: new-uri })
    (ok true))
)
