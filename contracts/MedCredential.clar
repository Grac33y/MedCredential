;; MedCredential - Healthcare credential verification platform
;; Providers earn tokens based on credential verification and patient ratings

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_ALREADY_VERIFIED (err u104))
(define-constant ERR_ALREADY_RATED (err u105))
(define-constant ERR_SELF_RATING (err u106))
(define-constant ERR_EMPTY_STRING (err u107))
(define-constant ERR_INVALID_RATING (err u108))
(define-constant ERR_INVALID_CREDENTIAL_ID (err u109))
(define-constant ERR_EMPTY_HASH (err u110))

;; Constants
(define-constant MAX_RATING u5)
(define-constant CONSULTATION_REWARD u10)
(define-constant SATISFACTION_REWARD u20)
(define-constant VERIFICATION_REWARD u50)

;; Data maps
(define-map providers
  { provider-id: principal }
  { name: (string-ascii 50), specialty: (string-ascii 50), reputation: uint, tokens: uint, verified: bool }
)

(define-map credentials
  { credential-id: uint }
  { 
    provider: principal, 
    description: (string-ascii 500), 
    credential-hash: (buff 32),
    timestamp: uint, 
    verified: bool,
    verification-count: uint,
    consultation-count: uint,
    satisfaction-rating: uint,
    rating-count: uint
  }
)

(define-map credential-verifications
  { credential-id: uint, verifier: principal }
  { verified: bool }
)

(define-map consultations
  { credential-id: uint, patient: principal }
  { consulted: bool, consultation-notes: (string-ascii 100) }
)

(define-map patient-ratings
  { credential-id: uint, rater: principal }
  { rating: uint }
)

;; Variables
(define-data-var next-credential-id uint u1)
(define-data-var action-counter uint u0)

;; Helper functions
(define-private (is-valid-credential-id (credential-id uint))
  (< credential-id (var-get next-credential-id))
)

;; Provider functions
(define-public (register-provider (name (string-ascii 50)) (specialty (string-ascii 50)))
  (let ((caller tx-sender))
    ;; Validate name is not empty
    (asserts! (> (len name) u0) ERR_EMPTY_STRING)
    ;; Validate specialty is not empty
    (asserts! (> (len specialty) u0) ERR_EMPTY_STRING)
    ;; Check if provider already exists
    (asserts! (is-none (map-get? providers {provider-id: caller})) ERR_ALREADY_EXISTS)
    ;; Register provider
    (ok (map-set providers 
      {provider-id: caller} 
      {name: name, specialty: specialty, reputation: u0, tokens: u100, verified: false}))
  )
)

(define-public (update-provider-info (name (string-ascii 50)) (specialty (string-ascii 50)))
  (let ((caller tx-sender))
    ;; Validate name is not empty
    (asserts! (> (len name) u0) ERR_EMPTY_STRING)
    ;; Validate specialty is not empty
    (asserts! (> (len specialty) u0) ERR_EMPTY_STRING)
    ;; Check if provider exists
    (asserts! (is-some (map-get? providers {provider-id: caller})) ERR_NOT_FOUND)
    ;; Update provider info
    (ok (map-set providers 
      {provider-id: caller} 
      (merge (unwrap! (map-get? providers {provider-id: caller}) ERR_NOT_FOUND)
             {name: name, specialty: specialty})))
  )
)

;; Credential functions
(define-public (submit-credential (description (string-ascii 500)) (credential-hash (buff 32)))
  (let ((caller tx-sender)
        (credential-id (var-get next-credential-id)))
    ;; Validate description is not empty
    (asserts! (> (len description) u0) ERR_EMPTY_STRING)
    ;; Validate credential-hash is not empty
    (asserts! (> (len credential-hash) u0) ERR_EMPTY_HASH)
    ;; Check if provider exists
    (asserts! (is-some (map-get? providers {provider-id: caller})) ERR_NOT_FOUND)
    ;; Increment action counter
    (var-set action-counter (+ (var-get action-counter) u1))
    
    ;; Create credential with validated data
    (map-set credentials 
      {credential-id: credential-id} 
      { 
        provider: caller, 
        description: description, 
        credential-hash: credential-hash,
        timestamp: (var-get action-counter), 
        verified: false,
        verification-count: u0,
        consultation-count: u0,
        satisfaction-rating: u0,
        rating-count: u0
      })
    ;; Increment credential ID
    (var-set next-credential-id (+ credential-id u1))
    (ok credential-id)
  )
)

(define-public (verify-credential (credential-id uint))
  (let ((caller tx-sender))
    ;; Validate credential-id
    (asserts! (is-valid-credential-id credential-id) ERR_INVALID_CREDENTIAL_ID)
    ;; Check if provider exists
    (asserts! (is-some (map-get? providers {provider-id: caller})) ERR_NOT_FOUND)
    ;; Check if credential exists
    (asserts! (is-some (map-get? credentials {credential-id: credential-id})) ERR_NOT_FOUND)
    
    ;; Get credential data
    (let ((credential (unwrap! (map-get? credentials {credential-id: credential-id}) ERR_NOT_FOUND)))
      ;; Check if provider is not the credential owner
      (asserts! (not (is-eq caller (get provider credential))) ERR_SELF_RATING)
      ;; Check if provider has not already verified this credential
      (asserts! (is-none (map-get? credential-verifications {credential-id: credential-id, verifier: caller})) ERR_ALREADY_VERIFIED)
      
      ;; Record verification with validated credential-id
      (map-set credential-verifications 
        {credential-id: credential-id, verifier: caller} 
        {verified: true})
      
      ;; Update credential verification count
      (let ((new-verification-count (+ (get verification-count credential) u1))
            (credential-provider (unwrap! (map-get? providers {provider-id: (get provider credential)}) ERR_NOT_FOUND))
            (verifier-provider (unwrap! (map-get? providers {provider-id: caller}) ERR_NOT_FOUND)))
        
        ;; Update credential data with validated credential-id
        (map-set credentials 
          {credential-id: credential-id} 
          (merge credential {
            verification-count: new-verification-count,
            verified: (>= new-verification-count u3)
          }))
        
        ;; Reward verifier with tokens
        (map-set providers 
          {provider-id: caller} 
          (merge verifier-provider {
            tokens: (+ (get tokens verifier-provider) u5),
            reputation: (+ (get reputation verifier-provider) u1)
          }))
        
        ;; If credential becomes verified (3+ verifications), reward provider
        (if (and (>= new-verification-count u3) (not (get verified credential)))
          (map-set providers 
            {provider-id: (get provider credential)} 
            (merge credential-provider {
              tokens: (+ (get tokens credential-provider) VERIFICATION_REWARD),
              reputation: (+ (get reputation credential-provider) u10),
              verified: true
            }))
          true)
        
        (ok new-verification-count)
      )
    )
  )
)

(define-public (record-consultation (credential-id uint) (consultation-notes (string-ascii 100)))
  (let ((caller tx-sender))
    ;; Validate credential-id
    (asserts! (is-valid-credential-id credential-id) ERR_INVALID_CREDENTIAL_ID)
    ;; Validate consultation notes is not empty
    (asserts! (> (len consultation-notes) u0) ERR_EMPTY_STRING)
    ;; Check if patient exists (anyone can be a patient)
    ;; Check if credential exists
    (asserts! (is-some (map-get? credentials {credential-id: credential-id})) ERR_NOT_FOUND)
    
    ;; Get credential data
    (let ((credential (unwrap! (map-get? credentials {credential-id: credential-id}) ERR_NOT_FOUND)))
      ;; Check if patient has not already consulted with this credential
      (asserts! (is-none (map-get? consultations {credential-id: credential-id, patient: caller})) ERR_ALREADY_EXISTS)
      
      ;; Record consultation with validated credential-id
      (map-set consultations 
        {credential-id: credential-id, patient: caller} 
        {consulted: true, consultation-notes: consultation-notes})
      
      ;; Update credential consultation count
      (let ((new-consultation-count (+ (get consultation-count credential) u1))
            (credential-provider (unwrap! (map-get? providers {provider-id: (get provider credential)}) ERR_NOT_FOUND)))
        
        ;; Update credential data with validated credential-id
        (map-set credentials 
          {credential-id: credential-id} 
          (merge credential {consultation-count: new-consultation-count}))
        
        ;; Reward provider with tokens for consultation
        (map-set providers 
          {provider-id: (get provider credential)} 
          (merge credential-provider {
            tokens: (+ (get tokens credential-provider) CONSULTATION_REWARD)
          }))
        
        (ok new-consultation-count)
      )
    )
  )
)

(define-public (rate-provider-satisfaction (credential-id uint) (rating uint))
  (let ((caller tx-sender))
    ;; Validate credential-id
    (asserts! (is-valid-credential-id credential-id) ERR_INVALID_CREDENTIAL_ID)
    ;; Validate rating (1-5)
    (asserts! (and (>= rating u1) (<= rating MAX_RATING)) ERR_INVALID_RATING)
    ;; Check if credential exists
    (asserts! (is-some (map-get? credentials {credential-id: credential-id})) ERR_NOT_FOUND)
    
    ;; Get credential data
    (let ((credential (unwrap! (map-get? credentials {credential-id: credential-id}) ERR_NOT_FOUND)))
      ;; Check if patient is not the provider
      (asserts! (not (is-eq caller (get provider credential))) ERR_SELF_RATING)
      ;; Check if patient has consulted with this provider
      (asserts! (is-some (map-get? consultations {credential-id: credential-id, patient: caller})) ERR_NOT_FOUND)
      ;; Check if patient has not already rated this credential
      (asserts! (is-none (map-get? patient-ratings {credential-id: credential-id, rater: caller})) ERR_ALREADY_RATED)
      
      ;; Record rating with validated credential-id and rating
      (map-set patient-ratings 
        {credential-id: credential-id, rater: caller} 
        {rating: rating})
      
      ;; Update credential rating
      (let ((current-total-rating (* (get satisfaction-rating credential) (get rating-count credential)))
            (new-rating-count (+ (get rating-count credential) u1))
            (new-total-rating (+ current-total-rating rating))
            (new-average-rating (/ new-total-rating new-rating-count))
            (credential-provider (unwrap! (map-get? providers {provider-id: (get provider credential)}) ERR_NOT_FOUND)))
        
        ;; Update credential data with validated credential-id
        (map-set credentials 
          {credential-id: credential-id} 
          (merge credential {
            satisfaction-rating: new-average-rating,
            rating-count: new-rating-count
          }))
        
        ;; Reward provider based on rating
        (if (>= rating u4)
          (map-set providers 
            {provider-id: (get provider credential)} 
            (merge credential-provider {
              tokens: (+ (get tokens credential-provider) SATISFACTION_REWARD),
              reputation: (+ (get reputation credential-provider) u5)
            }))
          true)
        
        (ok new-average-rating)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-provider-info (provider-id principal))
  (map-get? providers {provider-id: provider-id})
)

(define-read-only (get-credential (credential-id uint))
  (map-get? credentials {credential-id: credential-id})
)

(define-read-only (get-credential-verification (credential-id uint) (verifier principal))
  (map-get? credential-verifications {credential-id: credential-id, verifier: verifier})
)

(define-read-only (get-consultation (credential-id uint) (patient principal))
  (map-get? consultations {credential-id: credential-id, patient: patient})
)

(define-read-only (get-patient-rating (credential-id uint) (rater principal))
  (map-get? patient-ratings {credential-id: credential-id, rater: rater})
)

(define-read-only (get-total-credentials)
  (- (var-get next-credential-id) u1)
)