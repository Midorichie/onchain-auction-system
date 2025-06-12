;; On-Chain Auction System - Phase 2
;; Enhanced Multi-Auction System with Security Improvements

;; Constants for error handling
(define-constant ERR-NOT-FOUND u100)
(define-constant ERR-UNAUTHORIZED u101)
(define-constant ERR-AUCTION-INACTIVE u102)
(define-constant ERR-AUCTION-ENDED u103)
(define-constant ERR-BID-TOO-LOW u104)
(define-constant ERR-AUCTION-ACTIVE u105)
(define-constant ERR-INSUFFICIENT-FUNDS u106)
(define-constant ERR-INVALID-DURATION u107)
(define-constant ERR-INVALID-PRICE u108)

;; Minimum auction duration (24 hours in blocks, assuming ~10 min blocks)
(define-constant MIN-AUCTION-DURATION u144)
(define-constant MAX-AUCTION-DURATION u4320) ;; 30 days
(define-constant MIN-BID-INCREMENT u1000000) ;; 1 STX minimum increment

;; Data variables
(define-data-var next-auction-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Data maps
(define-map auctions
  {id: uint}
  {owner: principal,
   item-description: (string-ascii 256),
   start-price: uint,
   end-block: uint,
   highest-bid: uint,
   highest-bidder: principal,
   is-active: bool,
   created-at: uint})

(define-map bidder-refunds
  {auction-id: uint, bidder: principal}
  {amount: uint})

(define-map auction-stats
  {id: uint}
  {total-bids: uint,
   unique-bidders: uint})

;; Private functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner)))

(define-private (get-next-auction-id)
  (let ((current-id (var-get next-auction-id)))
    (var-set next-auction-id (+ current-id u1))
    current-id))

(define-private (is-valid-auction-id (auction-id uint))
  (and (> auction-id u0) (< auction-id (var-get next-auction-id))))

(define-private (is-valid-description (description (string-ascii 256)))
  (> (len description) u0))

(define-private (update-bidder-stats (auction-id uint) (bidder principal))
  (if (is-valid-auction-id auction-id)
    (let ((current-stats (default-to {total-bids: u0, unique-bidders: u0} 
                                    (map-get? auction-stats {id: auction-id}))))
      (map-set auction-stats
        {id: auction-id}
        (merge current-stats {total-bids: (+ (get total-bids current-stats) u1)})))
    false))

;; Public functions
(define-public (create-auction (start-price uint) (duration uint) (description (string-ascii 256)))
  (let ((caller tx-sender)
        (auction-id (get-next-auction-id))
        (end-block (+ block-height duration)))
    (asserts! (> start-price u0) (err ERR-INVALID-PRICE))
    (asserts! (>= duration MIN-AUCTION-DURATION) (err ERR-INVALID-DURATION))
    (asserts! (<= duration MAX-AUCTION-DURATION) (err ERR-INVALID-DURATION))
    (asserts! (is-valid-description description) (err ERR-INVALID-PRICE))
    (map-set auctions
      {id: auction-id}
      {owner: caller,
       item-description: description,
       start-price: start-price,
       end-block: end-block,
       highest-bid: start-price,
       highest-bidder: caller,
       is-active: true,
       created-at: block-height})
    (map-set auction-stats
      {id: auction-id}
      {total-bids: u0, unique-bidders: u0})
    (ok auction-id)))

(define-public (place-bid (auction-id uint))
  (let ((auction-opt (map-get? auctions {id: auction-id}))
        (bid-amount (stx-get-balance tx-sender)))
    (asserts! (is-valid-auction-id auction-id) (err ERR-NOT-FOUND))
    (match auction-opt
      auction-data
      (let ((caller tx-sender)
            (current-highest (get highest-bid auction-data))
            (end-block (get end-block auction-data))
            (current-bidder (get highest-bidder auction-data)))
        (asserts! (get is-active auction-data) (err ERR-AUCTION-INACTIVE))
        (asserts! (<= block-height end-block) (err ERR-AUCTION-ENDED))
        (asserts! (> bid-amount (+ current-highest MIN-BID-INCREMENT)) (err ERR-BID-TOO-LOW))
        (asserts! (not (is-eq caller (get owner auction-data))) (err ERR-UNAUTHORIZED))
        
        ;; Transfer STX from bidder to contract
        (try! (stx-transfer? bid-amount caller (as-contract tx-sender)))
        
        ;; Refund previous highest bidder if not the auction owner
        (if (not (is-eq current-bidder (get owner auction-data)))
            (try! (as-contract (stx-transfer? current-highest tx-sender current-bidder)))
            true)
        
        ;; Update auction with new highest bid
        (map-set auctions
          {id: auction-id}
          (merge auction-data {highest-bid: bid-amount, highest-bidder: caller}))
        
        ;; Update stats
        (update-bidder-stats auction-id caller)
        
        (ok bid-amount))
      (err ERR-NOT-FOUND))))

(define-public (close-auction (auction-id uint))
  (let ((auction-opt (map-get? auctions {id: auction-id})))
    (asserts! (is-valid-auction-id auction-id) (err ERR-NOT-FOUND))
    (match auction-opt
      auction-data
      (let ((caller tx-sender)
            (owner (get owner auction-data))
            (end-block (get end-block auction-data))
            (highest-bid (get highest-bid auction-data))
            (winner (get highest-bidder auction-data)))
        (asserts! (is-eq caller owner) (err ERR-UNAUTHORIZED))
        (asserts! (> block-height end-block) (err ERR-AUCTION-ACTIVE))
        (asserts! (get is-active auction-data) (err ERR-AUCTION-INACTIVE))
        
        ;; Mark auction as closed
        (map-set auctions
          {id: auction-id}
          (merge auction-data {is-active: false}))
        
        ;; Transfer proceeds to auction owner (if there was a valid bid)
        (if (not (is-eq winner owner))
            (try! (as-contract (stx-transfer? highest-bid tx-sender owner)))
            true)
        
        (ok {winner: winner, final-price: highest-bid}))
      (err ERR-NOT-FOUND))))

(define-public (emergency-close (auction-id uint))
  (let ((auction-opt (map-get? auctions {id: auction-id})))
    (asserts! (is-contract-owner) (err ERR-UNAUTHORIZED))
    (asserts! (is-valid-auction-id auction-id) (err ERR-NOT-FOUND))
    (match auction-opt
      auction-data
      (let ((highest-bid (get highest-bid auction-data))
            (winner (get highest-bidder auction-data))
            (owner (get owner auction-data)))
        (asserts! (get is-active auction-data) (err ERR-AUCTION-INACTIVE))
        
        ;; Mark auction as closed
        (map-set auctions
          {id: auction-id}
          (merge auction-data {is-active: false}))
        
        ;; Refund highest bidder if not owner
        (if (not (is-eq winner owner))
            (try! (as-contract (stx-transfer? highest-bid tx-sender winner)))
            true)
        
        (ok true))
      (err ERR-NOT-FOUND))))

;; Read-only functions
(define-read-only (get-auction (auction-id uint))
  (map-get? auctions {id: auction-id}))

(define-read-only (get-auction-stats (auction-id uint))
  (map-get? auction-stats {id: auction-id}))

(define-read-only (get-current-auction-id)
  (- (var-get next-auction-id) u1))

(define-read-only (is-auction-active (auction-id uint))
  (match (map-get? auctions {id: auction-id})
    auction-data
    (and (get is-active auction-data) 
         (<= block-height (get end-block auction-data)))
    false))

(define-read-only (get-time-remaining (auction-id uint))
  (match (map-get? auctions {id: auction-id})
    auction-data
    (if (<= block-height (get end-block auction-data))
        (ok (- (get end-block auction-data) block-height))
        (ok u0))
    (err ERR-NOT-FOUND)))

(define-read-only (get-contract-owner)
  (var-get contract-owner))
