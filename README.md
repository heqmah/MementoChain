# MementoChain

A decentralized memory sharing platform built on the Stacks blockchain that allows users to create, share, and discover time-locked digital memories in a secure and privacy-focused way.

## Overview

MementoChain is a smart contract platform that enables users to store and share digital memories with customizable unlock times, privacy settings, and recipient controls. Built using Clarity smart contracts on the Stacks blockchain, it provides a trustless and transparent way to preserve and share meaningful moments.

## Features

### Memory Creation and Management
- Create time-locked digital memories with customizable unlock delays
- Support for multiple content types (text, photo, audio)
- Privacy controls including anonymous posting
- Targeted sharing with specific recipients
- Content tagging system for better organization
- Customizable titles and descriptions

### Memory Interaction
- Claim memories once they're unlocked
- Like and interact with public memories
- Report inappropriate content
- Random memory discovery feature
- Track user engagement statistics

### Privacy and Security
- Time-locked content with configurable unlock delays (1 to 52,560 blocks)
- Optional anonymous posting
- Recipient-specific memory sharing
- Content moderation through community reporting
- Creator-controlled deletion capabilities

### Platform Features
- Contract pause/unpause functionality for maintenance
- Comprehensive input validation
- User interaction tracking
- Memory metadata storage
- Like/interaction tracking system

## Technical Specifications

### Memory Structure
- Content hash (256 characters max)
- Title (64 characters max)
- Description (256 characters max)
- Memory type (text/photo/audio)
- Unlock delay (1-52,560 blocks)
- Anonymous flag
- Optional recipient
- Tags (up to 5 tags, 32 characters each)

### Core Functions

#### Public Functions
```clarity
create-memory: Create a new time-locked memory
claim-memory: Claim an unlocked memory
like-memory: Like an unlocked memory
report-memory: Report inappropriate content
delete-memory: Delete owned memories
get-random-memory: Discover random unclaimed memories
```

#### Read-Only Functions
```clarity
get-memory-details: Retrieve memory details if unlocked
get-user-stats: Get user interaction statistics
get-total-memories: Get total number of memories
is-memory-liked-by-user: Check if a user has liked a memory
```

### Error Handling
Comprehensive error handling for:
- Ownership validation
- Content validation
- Time-lock enforcement
- Privacy controls
- Platform state management

## Usage Examples

### Creating a Memory
```clarity
(contract-call? .memento-chain create-memory
    "QmHash..."                ;; content-hash
    "My First Memory"          ;; title
    "A special moment..."      ;; description
    "text"                     ;; memory-type
    u1440                      ;; unlock-delay (blocks)
    false                      ;; is-anonymous
    none                       ;; recipient (optional)
    (list "personal" "2024")   ;; tags
)
```

### Claiming a Memory
```clarity
(contract-call? .memento-chain claim-memory u1)  ;; memory-id
```

## Security Considerations

- All user inputs are validated and sanitized
- Time-locks are enforced at the contract level
- Privacy controls are strictly maintained
- Content moderation system in place
- Contract can be paused in case of emergencies


