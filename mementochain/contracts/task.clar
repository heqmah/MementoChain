;; MementoChain - Decentralized Memory Sharing Platform
;; Written in Clarity for Stacks blockchain

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-claimed (err u101))
(define-constant err-not-unlocked (err u102))
(define-constant err-invalid-memory (err u103))

;; Data Variables
(define-data-var total-memories uint u0)
(define-data-var random-seed uint u1)

;; Define memory structure
(define-map memories uint {
    creator: principal,
    content-hash: (string-utf8 256),
    unlock-height: uint,
    is-anonymous: bool,
    is-claimed: bool,
    recipient: (optional principal)
})

;; Define memory metadata
(define-map memory-metadata uint {
    title: (string-utf8 64),
    description: (string-utf8 256),
    memory-type: (string-utf8 16),  ;; "text", "photo", "audio"
    creation-height: uint
})

;; Public functions

;; Create a new memory
(define-public (create-memory (content-hash (string-utf8 256)) 
                            (title (string-utf8 64))
                            (description (string-utf8 256))
                            (memory-type (string-utf8 16))
                            (unlock-delay uint)
                            (is-anonymous bool)
                            (recipient (optional principal)))
    (let ((memory-id (var-get total-memories))
          (unlock-height (+ block-height unlock-delay)))
        
        ;; Store memory data
        (map-set memories memory-id {
            creator: tx-sender,
            content-hash: content-hash,
            unlock-height: unlock-height,
            is-anonymous: is-anonymous,
            is-claimed: false,
            recipient: recipient
        })
        
        ;; Store metadata
        (map-set memory-metadata memory-id {
            title: title,
            description: description,
            memory-type: memory-type,
            creation-height: block-height
        })
        
        ;; Increment total memories
        (var-set total-memories (+ memory-id u1))
        (ok memory-id)))

;; Claim a memory (for time-locked or targeted memories)
(define-public (claim-memory (memory-id uint))
    (let ((memory (unwrap! (map-get? memories memory-id) (err err-invalid-memory))))
        (asserts! (>= block-height (get unlock-height memory)) (err err-not-unlocked))
        (asserts! (not (get is-claimed memory)) (err err-already-claimed))
        (asserts! (or
            (is-none (get recipient memory))
            (is-eq (some tx-sender) (get recipient memory)))
            (err err-owner-only))
        
        ;; Mark as claimed
        (map-set memories memory-id (merge memory { is-claimed: true }))
        (ok true)))

;; Get a random unclaimed memory
(define-public (get-random-memory)
    (let ((current-seed (var-get random-seed))
          (total (var-get total-memories)))
        
        ;; Update random seed
        (var-set random-seed (+ current-seed block-height))
        
        ;; Get random memory ID
        (let ((random-id (mod current-seed total)))
            (ok (unwrap! (map-get? memories random-id) (err err-invalid-memory))))))

;; Read functions

;; Get memory details if unlocked
(define-read-only (get-memory-details (memory-id uint))
    (let ((memory (unwrap! (map-get? memories memory-id) (err err-invalid-memory))))
        (if (>= block-height (get unlock-height memory))
            (ok {
                memory: memory,
                metadata: (unwrap! (map-get? memory-metadata memory-id) (err err-invalid-memory))
            })
            (err err-not-unlocked))))

;; Get total number of memories
(define-read-only (get-total-memories)
    (ok (var-get total-memories)))
