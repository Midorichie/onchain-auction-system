# On-Chain Auction System - Phase 2

A secure, multi-auction system built on Stacks blockchain with enhanced security features and escrow functionality.

## 🚀 New Features in Phase 2

### Enhanced Security
- **Input validation**: All parameters are validated with meaningful error messages
- **Access controls**: Owner-only functions and bidder restrictions
- **Reentrancy protection**: Secure STX transfers with proper error handling
- **Emergency controls**: Contract owner can emergency-close auctions if needed

### Bug Fixes
- Fixed auction ID generation bug (was always returning 1)
- Corrected map operations (using `map-set` instead of `map-insert` for updates)
- Added proper STX balance checks before bidding
- Fixed bidder refund mechanism

### New Contracts
1. **Enhanced Auction Contract** (`auction.clar`)
2. **Escrow Contract** (`escrow.clar`) - For high-value auction security

### New Functionality
- **Automatic refunds**: Previous bidders get automatically refunded
- **Auction statistics**: Track total bids and unique bidders
- **Time-based controls**: Minimum/maximum auction durations
- **Item descriptions**: Auctions can include item descriptions
- **Escrow system**: Optional escrow for high-value transactions
- **Emergency controls**: Admin can resolve disputes and emergency situations

## 📋 Contract Overview

### Main Auction Contract Features
- Create multiple simultaneous auctions
- Secure bidding with automatic refunds
- Time-bounded auctions with validation
- Statistical tracking
- Emergency management functions

### Escrow Contract Features
- Secure fund holding for high-value auctions
- Dual confirmation system (buyer + seller)
- Dispute resolution mechanism
- Configurable fee structure
- Deadline enforcement

## 🛠 Usage

### Creating an Auction
```clarity
(contract-call? .auction create-auction u1000000 u1440 "Vintage Guitar")
;; Creates auction with 1 STX starting price, 10-day duration, and description
```

### Placing a Bid
```clarity
(contract-call? .auction place-bid u1)
;; Places bid on auction ID 1 using caller's STX balance
```

### Closing an Auction
```clarity
(contract-call? .auction close-auction u1)
;; Closes auction ID 1 (only auction owner can call this after end time)
```

### Using Escrow (Optional)
```clarity
;; Create escrow agreement
(contract-call? .escrow create-escrow u1 'SP1SELLER 'SP1BUYER u5000000 u2880)

;; Buyer deposits funds
(contract-call? .escrow deposit-funds u1)

;; Both parties confirm delivery
(contract-call? .escrow confirm-delivery u1)
```

## 🔒 Security Features

### Input Validation
- Minimum auction duration: 24 hours (144 blocks)
- Maximum auction duration: 30 days (4320 blocks)
- Minimum bid increment: 1 STX
- Non-zero starting prices required

### Access Controls
- Only auction owners can close their auctions
- Auction owners cannot bid on their own auctions
- Contract owner has emergency powers
- Escrow requires proper authorization

### Error Handling
All functions return meaningful error codes:
- `u100`: Not found
- `u101`: Unauthorized
- `u102`: Auction inactive
- `u103`: Auction ended
- `u104`: Bid too low
- `u105`: Auction still active
- `u106`: Insufficient funds
- `u107`: Invalid duration
- `u108`: Invalid price

## 📊 Read-Only Functions

### Auction Information
- `get-auction`: Get complete auction details
- `get-auction-stats`: Get bidding statistics
- `is-auction-active`: Check if auction is currently active
- `get-time-remaining`: Get blocks remaining in auction
- `get-current-auction-id`: Get the latest auction ID

### Escrow Information
- `get-escrow`: Get escrow agreement details
- `get-escrow-fee-rate`: Get current escrow fee rate
- `calculate-escrow-fee`: Calculate fee for given amount

## 🧪 Testing

The contracts include comprehensive error handling and input validation. Test scenarios should cover:

1. **Happy Path Testing**
   - Create auction, place bids, close auction
   - Use escrow for high-value transactions

2. **Edge Case Testing**
   - Invalid durations and prices
   - Bidding on expired auctions
   - Unauthorized access attempts

3. **Security Testing**
   - Reentrancy protection
   - Access control bypasses
   - Emergency function usage

## 🔧 Configuration

### Auction Parameters
- `MIN-AUCTION-DURATION`: 144 blocks (~24 hours)
- `MAX-AUCTION-DURATION`: 4320 blocks (~30 days)
- `MIN-BID-INCREMENT`: 1,000,000 µSTX (1 STX)

### Escrow Parameters
- Default fee rate: 2.5% (250 basis points)
- Configurable by contract owner

## 🚧 Future Enhancements

- Multi-token support (SIP-010 tokens)
- Dutch auction implementation
- Auction categories and filtering
- Automated auction extensions
- Integration with NFT standards
