;; temp.clar - temporary file for testing changes
;; Will replace main contract once structure is verified

(define-constant ERR-NOT-POLICYHOLDER (err u100))
(define-constant ERR-ALREADY-CLAIMED (err u101))
(define-constant ERR-INSUFFICIENT-POOL (err u102))
(define-constant ERR-NOT-MEMBER (err u103))
(define-constant ERR-ALREADY-VOTED (err u104))
(define-constant ERR-NO-CLAIM (err u105))
(define-constant ERR-INVALID-ACTION (err u106))
(define-constant ERR-ZERO-AMOUNT (err u107))

;; State maps
(define-map members
  principal
  { contribution: uint }
)

(define-map policies
  uint
  { holder: principal, coverage: uint, premium: uint, active: bool }
)

(define-map claims
  uint
  { policy-id: uint, claimant: principal, description: (string-ascii 120), votes-for: uint, votes-against: uint, executed: bool }
)

(define-map claim-votes
  { claim-id: uint, voter: principal }
  bool
)

(define-data-var policy-counter uint u0)
(define-data-var claim-counter uint u0)

;; Events data vars
(define-data-var contributed-event (optional (tuple (who principal) (amount uint))) none)
(define-data-var policy-purchased-event (optional (tuple (policy-id uint) (holder principal) (coverage uint) (premium uint))) none)
(define-data-var claim-submitted-event (optional (tuple (claim-id uint) (policy-id uint) (claimant principal) (description (string-ascii 120)))) none)
(define-data-var claim-voted-event (optional (tuple (claim-id uint) (voter principal) (support bool) (power uint))) none)
(define-data-var claim-executed-event (optional (tuple (claim-id uint) (amount uint) (recipient principal))) none)

(define-private (handle-contribution)
  (begin
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (let ((existing (default-to { contribution: u0 } (map-get? members tx-sender))))
      (map-set members tx-sender { contribution: (+ (get contribution existing) amount) }))
    (var-set contributed-event (some {who: tx-sender, amount: amount}))
    (ok u1)))

(define-private (handle-policy-purchase)
  (begin
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (let ((id (+ (var-get policy-counter) u1)))
      (var-set policy-counter id)
      (map-set policies id { holder: tx-sender, coverage: coverage, premium: amount, active: true })
      (var-set policy-purchased-event (some {policy-id: id, holder: tx-sender, coverage: coverage, premium: amount}))
      (ok id))))

(define-private (handle-claim-submission)
  (let ((policy (unwrap! (map-get? policies target-id) ERR-NOT-POLICYHOLDER)))
    (asserts! (is-eq (get holder policy) tx-sender) ERR-NOT-POLICYHOLDER)
    (let ((cid (+ (var-get claim-counter) u1)))
      (var-set claim-counter cid)
      (map-set claims cid { policy-id: target-id, claimant: tx-sender, description: description, votes-for: u0, votes-against: u0, executed: false })
      (var-set claim-submitted-event (some {claim-id: cid, policy-id: target-id, claimant: tx-sender, description: description}))
      (ok cid))))

(define-private (handle-claim-vote)
  (let ((claim (unwrap! (map-get? claims target-id) ERR-NO-CLAIM))
        (member (unwrap! (map-get? members tx-sender) ERR-NOT-MEMBER)))
    (asserts! (is-none (map-get? claim-votes { claim-id: target-id, voter: tx-sender })) ERR-ALREADY-VOTED)
    (let ((power (get contribution member)))
      (if support
          (map-set claims target-id (merge claim { votes-for: (+ (get votes-for claim) power) }))
          (map-set claims target-id (merge claim { votes-against: (+ (get votes-against claim) power) })))
      (map-set claim-votes { claim-id: target-id, voter: tx-sender } true)
      (var-set claim-voted-event (some {claim-id: target-id, voter: tx-sender, support: support, power: power}))
      (ok u1))))

(define-private (handle-claim-execution)
  (let ((claim (unwrap! (map-get? claims target-id) ERR-NO-CLAIM)))
    (asserts! (not (get executed claim)) ERR-ALREADY-CLAIMED)
    (asserts! (> (get votes-for claim) (get votes-against claim)) ERR-NO-CLAIM)
    (let ((policy (unwrap! (map-get? policies (get policy-id claim)) ERR-NOT-POLICYHOLDER)))
      (let ((amt (get coverage policy)))
        (asserts! (>= (stx-get-balance (as-contract tx-sender)) amt) ERR-INSUFFICIENT-POOL)
        (try! (stx-transfer? amt (as-contract tx-sender) (get claimant claim)))
        (map-set claims target-id (merge claim { executed: true }))
        (map-set policies (get policy-id claim) (merge policy { active: false }))
        (var-set claim-executed-event (some {claim-id: target-id, amount: amt, recipient: (get claimant claim)}))
        (ok amt)))))

(define-public (poolAction 
  (action (string-ascii 20)) 
  (amount uint) 
  (coverage uint) 
  (description (string-ascii 120)) 
  (target-id uint) 
  (support bool) 
  (recipient principal)
)
  (if (is-eq action "contribute")
      (handle-contribution)
      (if (is-eq action "buy-policy")
          (handle-policy-purchase)
          (if (is-eq action "submit-claim")
              (handle-claim-submission)
              (if (is-eq action "vote-claim")
                  (handle-claim-vote)
                  (if (is-eq action "execute-claim")
                      (handle-claim-execution)
                      (if (is-eq action "get-member")
                          (ok (tuple (member (map-get? members recipient))))
                          (if (is-eq action "get-policy")
                              (ok (tuple (policy (map-get? policies target-id))))
                              (if (is-eq action "get-claim")
                                  (ok (tuple (claim (map-get? claims target-id))))
                                  (if (is-eq action "get-balance")
                                      (ok (tuple (balance (stx-get-balance (as-contract tx-sender)))))
                                      (err ERR-INVALID-ACTION))))))))))))
