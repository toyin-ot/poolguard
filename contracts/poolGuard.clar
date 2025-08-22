;; =====================================================
;; PoolGuard - Fully Combined Decentralized Insurance Pool
;; =====================================================
;; =====================================================

;; Constants for Error Codes
(define-constant ERR-NOT-POLICYHOLDER u100)
(define-constant ERR-ALREADY-CLAIMED u101)
(define-constant ERR-INSUFFICIENT-POOL u102)
(define-constant ERR-NOT-MEMBER u103)
(define-constant ERR-ALREADY-VOTED u104)
(define-constant ERR-NO-CLAIM u105)
(define-constant ERR-INVALID-ACTION u106)
(define-constant ERR-ZERO-AMOUNT u107)

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

;; Helper functions for each action
(define-private (handle-contribution (sender principal) (amount uint))
  (begin
    (if (> amount u0)
        (let ((transfer-result (stx-transfer? amount sender (as-contract tx-sender))))
          (match transfer-result
            success (let ((existing (default-to { contribution: u0 } (map-get? members sender))))
                      (map-set members sender { contribution: (+ (get contribution existing) amount) })
                      (var-set contributed-event (some {who: sender, amount: amount}))
                      (ok amount))
            error (err ERR-INSUFFICIENT-POOL)))
        (err ERR-ZERO-AMOUNT))))

(define-private (handle-policy-purchase (buyer principal) (amount uint) (coverage-amount uint))
  (begin
    (if (and (> amount u0) (> coverage-amount u0))
        (let ((transfer-result (stx-transfer? amount buyer (as-contract tx-sender))))
          (match transfer-result
            success (let ((id (+ (var-get policy-counter) u1)))
                      (var-set policy-counter id)
                      (map-set policies id { holder: buyer, coverage: coverage-amount, premium: amount, active: true })
                      (var-set policy-purchased-event (some {policy-id: id, holder: buyer, coverage: coverage-amount, premium: amount}))
                      (ok amount))
            error (err ERR-INSUFFICIENT-POOL)))
        (err ERR-ZERO-AMOUNT))))

(define-private (handle-claim-submission (claimer principal) (policy-id uint) (desc (string-ascii 120)))
  (let ((policy-opt (map-get? policies policy-id)))
    (match policy-opt
      policy (if (and (> policy-id u0) (is-eq (get holder policy) claimer))
                (let ((cid (+ (var-get claim-counter) u1)))
                  (var-set claim-counter cid)
                  (map-set claims cid { policy-id: policy-id, claimant: claimer, description: desc, votes-for: u0, votes-against: u0, executed: false })
                  (var-set claim-submitted-event (some {claim-id: cid, policy-id: policy-id, claimant: claimer, description: desc}))
                  (ok (get coverage policy)))
                (err ERR-NOT-POLICYHOLDER))
      (err ERR-INVALID-ACTION))))

(define-private (handle-claim-vote (voter principal) (claim-id uint) (vote-support bool))
  (let ((claim-opt (map-get? claims claim-id))
        (member-opt (map-get? members voter)))
    (match claim-opt
      claim (match member-opt
              member (if (and (> claim-id u0)
                            (is-none (map-get? claim-votes { claim-id: claim-id, voter: voter })))
                       (let ((power (get contribution member)))
                         (if vote-support
                             (map-set claims claim-id (merge claim { votes-for: (+ (get votes-for claim) power) }))
                             (map-set claims claim-id (merge claim { votes-against: (+ (get votes-against claim) power) })))
                         (map-set claim-votes { claim-id: claim-id, voter: voter } true)
                         (var-set claim-voted-event (some {claim-id: claim-id, voter: voter, support: vote-support, power: power}))
                         (ok power))
                       (err ERR-ALREADY-VOTED))
              (err ERR-NOT-MEMBER))
      (err ERR-NO-CLAIM))))

(define-private (handle-claim-execution (claim-id uint))
  (let ((claim-opt (map-get? claims claim-id)))
    (match claim-opt
      claim (let ((policy-opt (map-get? policies (get policy-id claim))))
              (match policy-opt
                policy (if (and (> claim-id u0)
                              (not (get executed claim))
                              (> (get votes-for claim) (get votes-against claim)))
                         (let ((amt (get coverage policy)))
                           (if (>= (stx-get-balance (as-contract tx-sender)) amt)
                               (let ((transfer-result (stx-transfer? amt (as-contract tx-sender) (get claimant claim))))
                                 (match transfer-result
                                   success (begin
                                            (map-set claims claim-id (merge claim { executed: true }))
                                            (map-set policies (get policy-id claim) (merge policy { active: false }))
                                            (var-set claim-executed-event (some {claim-id: claim-id, amount: amt, recipient: (get claimant claim)}))
                                            (ok amt))
                   error (err ERR-INSUFFICIENT-POOL)))
                               (err ERR-INSUFFICIENT-POOL)))
                         (err ERR-NO-CLAIM))
                (err ERR-NOT-POLICYHOLDER)))
      (err ERR-NO-CLAIM))))

;; Main public function to handle all actions
(define-public (poolAction 
    (action (string-ascii 20)) 
    (amount uint)
    (coverage-amount uint)
    (description (string-ascii 120))
    (target-id uint)
    (support bool)
    (recipient principal))
  (if (is-eq action "contribute")
      (if (> amount u0) 
          (handle-contribution tx-sender amount)
          (err ERR-ZERO-AMOUNT))
      (if (is-eq action "buy-policy")
          (if (and (> amount u0) (> coverage-amount u0))
              (handle-policy-purchase tx-sender amount coverage-amount)
              (err ERR-ZERO-AMOUNT))
          (if (is-eq action "submit-claim")
              (if (> target-id u0)
                  (handle-claim-submission tx-sender target-id description)
                  (err ERR-INVALID-ACTION))
              (if (is-eq action "vote-claim")
                  (if (> target-id u0)
                      (handle-claim-vote tx-sender target-id support)
                      (err ERR-INVALID-ACTION))
                  (if (is-eq action "execute-claim")
                      (if (> target-id u0)
                          (handle-claim-execution target-id)
                          (err ERR-INVALID-ACTION))
                      (ok u0)))))))
