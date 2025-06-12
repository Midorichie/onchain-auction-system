;; On-Chain Auction System
;; Single English auction implementation

(define-fungible-token auction-token)

(define-map auctions
  ((id uint))
  ((owner principal)
   (start-price uint)
   (end-block uint)
   (highest-bid uint)
   (highest-bidder principal)
   (is-active bool)))

(define-private (next-auction-id)
  (let ((current (default-to 0 (map-get? auctions ((id u0))))))
    u1))

(define-public (create-auction (start-price uint) (duration uint))
  (let ((caller (contract-caller))
        (auction-id (next-auction-id))
        (end (+ (get-block-height) duration)))
    (begin
      (map-insert auctions
        ((id auction-id))
        ((owner caller)
         (start-price start-price)
         (end-block end)
         (highest-bid start-price)
         (highest-bidder caller)
         (is-active true)))
      (ok auction-id))))

(define-public (place-bid (auction-id uint) (bid-amt uint))
  (let ((auction (map-get? auctions ((id auction-id)))))
    (match auction
      auction-data
      (let ((caller (contract-caller))
            (current-highest (get highest-bid auction-data))
            (end-block (get end-block auction-data)))
        (if (or (not (get is-active auction-data))
                (> (get-block-height) end-block)
                (<= bid-amt current-highest))
            (err u1)
            (begin
              (map-insert auctions
                ((id auction-id))
                ((owner (get owner auction-data))
                 (start-price (get start-price auction-data))
                 (end-block end-block)
                 (highest-bid bid-amt)
                 (highest-bidder caller)
                 (is-active true)))
              (ok bid-amt)))))
      (err u0))))

(define-public (close-auction (auction-id uint))
  (let ((auction (map-get? auctions ((id auction-id)))))
    (match auction
      auction-data
      (let ((caller (contract-caller))
            (owner (get owner auction-data))
            (end-block (get end-block auction-data)))
        (if (or (not (= caller owner)) (< (get-block-height) end-block))
            (err u1)
            (begin
              (map-set auctions
                ((id auction-id))
                (merge auction-data {is-active: false}))
              ;; Transfer proceeds and token here
              (ok (get highest-bid auction-data))))))
      (err u0))))
