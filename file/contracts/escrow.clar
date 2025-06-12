;; Auction Escrow Contract
;; Handles secure escrow for high-value auctions

;; Constants
(define-constant ERR-NOT-FOUND u200)
(define-constant ERR-UNAUTHORIZED u201)
(define-constant ERR-ALREADY-EXISTS u202)
(define-constant ERR-ESCROW-ACTIVE u203)
(define-constant ERR-INSUFFICIENT-FUNDS u204)
(define-constant ERR-DEADLINE-PASSED u205)

;; Data variables
(define-data-var escrow-fee-rate uint u250) ;; 2.5% in basis points
(define-data-var contract-owner principal tx-sender)

;; Escrow agreements
(define-map escrow-agreements
  {auction-id: uint}
  {seller: principal,
   buyer: principal,
   amount: uint,
   deadline: uint,
   seller-confirmed: bool,
   buyer-confirmed: bool,
   is-active: bool,
   created-at: uint})

;; Private functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner)))

(define-private (calculate-fee (amount uint))
  (/ (* amount (var-get escrow-fee-rate)) u10000))

(define-private (is-valid-principal (addr principal))
  (not (is-eq addr tx-sender)))

(define-private (is-valid-amount (amount uint))
  (> amount u0))

(define-private (is-valid-deadline (deadline uint))
  (> deadline block-height))

;; Public functions
(define-public (create-escrow (auction-id uint) (seller principal) (buyer principal) (amount uint) (deadline uint))
  (let ((existing (map-get? escrow-agreements {auction-id: auction-id})))
    (asserts! (is-none existing) (err ERR-ALREADY-EXISTS))
    (asserts! (> auction-id u0) (err ERR-NOT-FOUND))
    (asserts! (is-valid-amount amount) (err ERR-INSUFFICIENT-FUNDS))
    (asserts! (is-valid-deadline deadline) (err ERR-DEADLINE-PASSED))
    (asserts! (not (is-eq seller buyer)) (err ERR-UNAUTHORIZED))
    
    (map-set escrow-agreements
      {auction-id: auction-id}
      {seller: seller,
       buyer: buyer,
       amount: amount,
       deadline: deadline,
       seller-confirmed: false,
       buyer-confirmed: false,
       is-active: true,
       created-at: block-height})
    
    (ok true)))

(define-public (deposit-funds (auction-id uint))
  (let ((escrow-opt (map-get? escrow-agreements {auction-id: auction-id})))
    (match escrow-opt
      escrow-data
      (let ((caller tx-sender)
            (required-amount (get amount escrow-data))
            (fee (calculate-fee required-amount))
            (total-required (+ required-amount fee)))
        (asserts! (is-eq caller (get buyer escrow-data)) (err ERR-UNAUTHORIZED))
        (asserts! (get is-active escrow-data) (err ERR-ESCROW-ACTIVE))
        (asserts! (<= block-height (get deadline escrow-data)) (err ERR-DEADLINE-PASSED))
        
        ;; Transfer funds to contract
        (try! (stx-transfer? total-required caller (as-contract tx-sender)))
        
        (ok true))
      (err ERR-NOT-FOUND))))

(define-public (confirm-delivery (auction-id uint))
  (let ((escrow-opt (map-get? escrow-agreements {auction-id: auction-id})))
    (asserts! (> auction-id u0) (err ERR-NOT-FOUND))
    (match escrow-opt
      escrow-data
      (let ((caller tx-sender))
        (asserts! (get is-active escrow-data) (err ERR-ESCROW-ACTIVE))
        (asserts! (or (is-eq caller (get seller escrow-data)) 
                     (is-eq caller (get buyer escrow-data))) (err ERR-UNAUTHORIZED))
        
        (let ((updated-data 
               (if (is-eq caller (get seller escrow-data))
                   (merge escrow-data {seller-confirmed: true})
                   (merge escrow-data {buyer-confirmed: true}))))
          
          (map-set escrow-agreements {auction-id: auction-id} updated-data)
          
          ;; If both parties confirmed, release funds
          (if (and (get seller-confirmed updated-data) (get buyer-confirmed updated-data))
              (begin
                (map-set escrow-agreements 
                  {auction-id: auction-id} 
                  (merge updated-data {is-active: false}))
                (let ((amount (get amount escrow-data))
                      (fee (calculate-fee amount))
                      (net-amount (- amount fee)))
                  (try! (as-contract (stx-transfer? net-amount tx-sender (get seller escrow-data))))
                  (try! (as-contract (stx-transfer? fee tx-sender (var-get contract-owner))))
                  (ok {released: true, amount: net-amount})))
              (ok {released: false, amount: u0}))))
      (err ERR-NOT-FOUND))))

(define-public (dispute-resolution (auction-id uint) (release-to-buyer bool))
  (let ((escrow-opt (map-get? escrow-agreements {auction-id: auction-id})))
    (asserts! (is-contract-owner) (err ERR-UNAUTHORIZED))
    (asserts! (> auction-id u0) (err ERR-NOT-FOUND))
    (match escrow-opt
      escrow-data
      (let ((amount (get amount escrow-data))
            (fee (calculate-fee amount))
            (net-amount (- amount fee)))
        (asserts! (get is-active escrow-data) (err ERR-ESCROW-ACTIVE))
        
        (map-set escrow-agreements 
          {auction-id: auction-id} 
          (merge escrow-data {is-active: false}))
        
        (if release-to-buyer
            (try! (as-contract (stx-transfer? amount tx-sender (get buyer escrow-data))))
            (try! (as-contract (stx-transfer? net-amount tx-sender (get seller escrow-data)))))
        
        (try! (as-contract (stx-transfer? fee tx-sender (var-get contract-owner))))
        (ok true))
      (err ERR-NOT-FOUND))))

;; Read-only functions
(define-read-only (get-escrow (auction-id uint))
  (map-get? escrow-agreements {auction-id: auction-id}))

(define-read-only (get-escrow-fee-rate)
  (var-get escrow-fee-rate))

(define-read-only (calculate-escrow-fee (amount uint))
  (calculate-fee amount))
