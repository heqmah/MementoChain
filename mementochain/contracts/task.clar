;; MementoChain - Decentralized Memory Sharing Platform
;; Written in Clarity for Stacks blockchain

;; Error codes
(define-constant err-owner-only (err u100))
(define-constant err-already-claimed (err u101))
(define-constant err-not-unlocked (err u102))
(define-constant err-invalid-memory (err u103))
(define-constant err-memory-locked (err u104))
(define-constant err-invalid-unlock-delay (err u105))
(define-constant err-invalid-title-length (err u106))
(define-constant err-invalid-description-length (err u107))
(define-constant err-invalid-memory-type (err u108))
(define-constant err-memory-deleted (err u109))
(define-constant err-self-transfer (err u110))
(define-constant err-contract-paused (err u111))

;; Constants
(define-constant contract-owner tx-sender)
(define-constant max-title-length u64)
(define-constant max-description-length u256)
(define-constant min-unlock-delay u1)
(define-constant max-unlock-delay u52560) ;; Approximately 1 year in blocks
(define-constant text-type "text")
(define-constant photo-type "photo")
(define-constant audio-type "audio")

;; Data Variables
(define-data-var total-memories uint u0)
(define-data-var random-seed uint u1)
(define-data-var contract-paused bool false)

;; Define memory structure
(define-map memories uint {
    creator: principal,
    content-hash: (string-ascii 256),
    unlock-height: uint,
    is-anonymous: bool,
    is-claimed: bool,
    is-deleted: bool,
    recipient: (optional principal),
    likes: uint,
    reports: uint,
    memory-type: (string-ascii 5)
})

;; Define memory metadata
(define-map memory-metadata uint {
    title: (string-ascii 64),
    description: (string-ascii 256),
    creation-height: uint,
    last-modified: uint,
    tags: (list 5 (string-ascii 32))
})

;; User interaction tracking
(define-map user-interactions principal {
    memories-created: uint,
    memories-claimed: uint,
    likes-given: uint
})

;; Memory likes tracking
(define-map memory-likes (tuple (memory-id uint) (user principal)) bool)

;; Private functions
(define-private (is-valid-memory-type (memory-type (string-ascii 5)))
    (or 
        (is-eq memory-type text-type)
        (is-eq memory-type photo-type)
        (is-eq memory-type audio-type)
    ))

(define-private (validate-memory-params 
    (title (string-ascii 64))
    (description (string-ascii 256))
    (memory-type (string-ascii 5))
    (unlock-delay uint))
    (begin
        (asserts! (<= (len title) max-title-length) (err err-invalid-title-length))
        (asserts! (<= (len description) max-description-length) (err err-invalid-description-length))
        (asserts! (and (>= unlock-delay min-unlock-delay) (<= unlock-delay max-unlock-delay)) (err err-invalid-unlock-delay))
        (asserts! (is-valid-memory-type memory-type) (err err-invalid-memory-type))
        (ok true)))

(define-private (update-user-stats (user principal) (action (string-ascii 6)))
    (let ((current-stats (default-to 
            { memories-created: u0, memories-claimed: u0, likes-given: u0 }
            (map-get? user-interactions user))))
        (if (is-eq action "create")
            (map-set user-interactions user (merge current-stats { memories-created: (+ (get memories-created current-stats) u1) }))
            (if (is-eq action "claim")
                (map-set user-interactions user (merge current-stats { memories-claimed: (+ (get memories-claimed current-stats) u1) }))
                (if (is-eq action "like")
                    (map-set user-interactions user (merge current-stats { likes-given: (+ (get likes-given current-stats) u1) }))
                    false)))))

;; Public functions

;; Contract management
(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
        (ok (var-set contract-paused (not (var-get contract-paused))))))

;; Create a new memory
(define-public (create-memory 
    (content-hash (string-ascii 256)) 
    (title (string-ascii 64))
    (description (string-ascii 256))
    (memory-type (string-ascii 5))
    (unlock-delay uint)
    (is-anonymous bool)
    (recipient (optional principal))
    (tags (list 5 (string-ascii 32))))
    
    (begin
        (asserts! (not (var-get contract-paused)) (err err-contract-paused))
        (match (validate-memory-params title description memory-type unlock-delay)
            success (let ((memory-id (var-get total-memories))
                         (unlock-height (+ block-height unlock-delay)))
                
                ;; Store memory data
                (map-set memories memory-id {
                    creator: tx-sender,
                    content-hash: content-hash,
                    unlock-height: unlock-height,
                    is-anonymous: is-anonymous,
                    is-claimed: false,
                    is-deleted: false,
                    recipient: recipient,
                    likes: u0,
                    reports: u0,
                    memory-type: memory-type
                })
                
                ;; Store metadata
                (map-set memory-metadata memory-id {
                    title: title,
                    description: description,
                    creation-height: block-height,
                    last-modified: block-height,
                    tags: tags
                })
                
                ;; Update stats
                (update-user-stats tx-sender "create")
                
                ;; Increment total memories
                (var-set total-memories (+ memory-id u1))
                (ok memory-id))
            error (err error))))

;; Claim a memory
(define-public (claim-memory (memory-id uint))
    (let ((memory (unwrap! (map-get? memories memory-id) (err err-invalid-memory))))
        (asserts! (not (var-get contract-paused)) (err err-contract-paused))
        (asserts! (not (get is-deleted memory)) (err err-memory-deleted))
        (asserts! (>= block-height (get unlock-height memory)) (err err-not-unlocked))
        (asserts! (not (get is-claimed memory)) (err err-already-claimed))
        (asserts! (or
            (is-none (get recipient memory))
            (is-eq (some tx-sender) (get recipient memory)))
            (err err-owner-only))
        
        ;; Mark as claimed and update stats
        (map-set memories memory-id (merge memory { is-claimed: true }))
        (update-user-stats tx-sender "claim")
        (ok true)))

;; Like a memory
(define-public (like-memory (memory-id uint))
    (let ((memory (unwrap! (map-get? memories memory-id) (err err-invalid-memory)))
          (like-key {memory-id: memory-id, user: tx-sender}))
        (asserts! (not (var-get contract-paused)) (err err-contract-paused))
        (asserts! (not (get is-deleted memory)) (err err-memory-deleted))
        (asserts! (>= block-height (get unlock-height memory)) (err err-not-unlocked))
        (asserts! (is-none (map-get? memory-likes like-key)) (err err-already-claimed))
        
        ;; Update likes count and record user interaction
        (map-set memories memory-id (merge memory { likes: (+ (get likes memory) u1) }))
        (map-set memory-likes like-key true)
        (update-user-stats tx-sender "like")
        (ok true)))

;; Report inappropriate content
(define-public (report-memory (memory-id uint))
    (let ((memory (unwrap! (map-get? memories memory-id) (err err-invalid-memory))))
        (asserts! (not (var-get contract-paused)) (err err-contract-paused))
        (asserts! (not (get is-deleted memory)) (err err-memory-deleted))
        
        ;; Increment report count
        (map-set memories memory-id (merge memory { reports: (+ (get reports memory) u1) }))
        (ok true)))

;; Delete memory (only creator or contract owner)
(define-public (delete-memory (memory-id uint))
    (let ((memory (unwrap! (map-get? memories memory-id) (err err-invalid-memory))))
        (asserts! (or 
            (is-eq tx-sender (get creator memory))
            (is-eq tx-sender contract-owner))
            (err err-owner-only))
        
        (map-set memories memory-id (merge memory { is-deleted: true }))
        (ok true)))

;; Get a random unclaimed memory
(define-public (get-random-memory)
    (let ((current-seed (var-get random-seed))
          (total (var-get total-memories)))
        
        (asserts! (not (var-get contract-paused)) (err err-contract-paused))
        
        ;; Update random seed
        (var-set random-seed (+ current-seed block-height))
        
        ;; Get random memory ID
        (let ((random-id (mod current-seed total)))
            (ok (unwrap! (map-get? memories random-id) (err err-invalid-memory))))))

;; Read functions

;; Get memory details if unlocked
(define-read-only (get-memory-details (memory-id uint))
    (let ((memory (unwrap! (map-get? memories memory-id) (err err-invalid-memory))))
        (asserts! (not (get is-deleted memory)) (err err-memory-deleted))
        (if (>= block-height (get unlock-height memory))
            (ok {
                memory: memory,
                metadata: (unwrap! (map-get? memory-metadata memory-id) (err err-invalid-memory))
            })
            (err err-not-unlocked))))

;; Get user statistics
(define-read-only (get-user-stats (user principal))
    (ok (default-to 
        { memories-created: u0, memories-claimed: u0, likes-given: u0 }
        (map-get? user-interactions user))))

;; Get total number of memories
(define-read-only (get-total-memories)
    (ok (var-get total-memories)))

;; Check if memory is liked by user
(define-read-only (is-memory-liked-by-user (memory-id uint) (user principal))
    (ok (is-some (map-get? memory-likes {memory-id: memory-id, user: user}))))