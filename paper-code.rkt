#lang racket
(require (for-syntax syntax/parse))
(provide (all-defined-out))

(define (((make-constraint-goal-constructor key) . terms) S/c)
  (let ((S (ext-S (car S/c) key terms)))
    (if (invalid? S) '() (list `(,S . ,(cdr S/c))))))

(define (ext-S S key terms)
  (hash-update S key ((curry cons) (apply list* terms))))

(define-syntax-rule (make-invalid? (cid ...) p ...)
  (λ (S) 
    (let ((cid (hash-ref S 'cid)) ...)
      (cond
        ((valid-== (hash-ref S '==))
         => (λ (s) (or (p s) ...)))
        (else #t)))))

(define-syntax (make-constraint-system stx)
  (syntax-parse stx
    [(_ (cid:id ...) p ...)
     (with-syntax 
       ([invalid? (syntax-local-introduce #'invalid?)]
        [S0 (syntax-local-introduce #'S0)]
        [== (syntax-local-introduce #'==)])
       #'(begin 
           (define invalid? (make-invalid? (cid ...) p ...))
           (define S0
             (make-immutable-hasheqv '((==) (cid) ...)))
           (define == (make-constraint-goal-constructor '==))
           (define cid (make-constraint-goal-constructor 'cid))
           ...))]))

(define (valid-== ==) 
  (foldr
    (λ (pr s) 
      (and s (unify (car pr) (cdr pr) s)))
    '()
    ==))

#| Term ⨯ Term ⨯ Subst ⟶ Bool |#  
(define (same-s? u v s) (equal? (unify u v s) s))

#| Term ⨯ Term ⨯ Subst ⟶ Bool |#  
(define (mem? u v s)
  (let ((v (walk v s)))
    (or (same-s? u v s)
        (and (pair? v)
             (or (mem? u (car v) s)
                 (mem? u (cdr v) s))))))

#| Term ⨯ Subst ⟶ Bool |#  
(define (walk-to-end x s)
  (let ((x (walk x s)))
    (if (pair? x) (walk-to-end (cdr x) s) x)))

#| Nat ⟶ Var |#
(define (var n) n)

#| Term ⟶ Bool |#
(define (var? n) (number? n))

#| Var ⨯ Term ⨯ Subst ⟶ Bool |#  
(define (occurs? x v s)
  (let ((v (walk v s)))
    (cond
      ((var? v) (eqv? x v))
      ((pair? v) (or (occurs? x (car v) s)
                     (occurs? x (cdr v) s)))
      (else #f))))

#| Var ⨯ Term ⨯ Subst ⟶ Maybe Subst |#
(define (ext-s x v s) 
  (cond 
    ((occurs? x v s) #f) 
    (else `((,x . ,v) . ,s))))

#| Term ⨯ Subst ⟶ Term |#  
(define (walk u s)
  (let ((pr (assv u s)))
    (if pr (walk (cdr pr) s) u)))

#| Term ⨯ Term ⨯ Subst ⟶ Maybe Subst |#  
(define (unify u v s)
  (let ((u (walk u s)) (v (walk v s)))
    (cond
      ((eqv? u v) s)
      ((var? u) (ext-s u v s))
      ((var? v) (ext-s v u s))
;o
      ((and (pair? u) (pair? v))
       (let ((s (unify (car u) (car v) s)))
         (and s (unify (cdr u) (cdr v) s))))
      (else #f))))

#| (Var ⟶ Goal) ⟶ State ⟶ Stream |#
(define ((call/fresh f) S/c)
  (let ((S (car S/c)) (c (cdr S/c)))
    ((f (var c)) `(,S . ,(+ 1 c)))))

#| Stream ⟶ Stream ⟶ Stream |#
(define ($append $1 $2)
  (cond
    ((null? $1) $2)
    ((promise? $1) (delay/name ($append $2 (force $1))))
    (else (cons (car $1) ($append (cdr $1) $2)))))

#| Goal ⟶ Stream ⟶ Stream |#
(define ($append-map g $)
  (cond
    ((null? $) `())
    ((promise? $) (delay/name ($append-map g (force $))))
    (else ($append (g (car $)) ($append-map g (cdr $))))))

#| Goal ⟶ Goal ⟶ Goal |#
(define ((disj g1 g2) S/c) ($append (g1 S/c) (g2 S/c)))

#| Goal ⟶ Goal ⟶ Goal |#
(define ((conj g1 g2) S/c) ($append-map g2 (g1 S/c)))

#| Stream ⟶ Mature Stream |#
(define (pull $) (if (promise? $) (pull (force $)) $))

#| Maybe Nat⁺ ⨯ Mature ⟶ List State |#
(define (take n $)
  (cond
    ((null? $) '())
    ((and n (zero? (- n 1))) (list (car (pull $))))
    (else (cons (car $) 
            (take (and n (- n 1)) (pull (cdr $)))))))

#| Maybe Nat⁺ ⨯ Goal ⟶ List State |#
(define (call/initial-state n g)
  (take n (pull (g `(,S0 . 0)))))

(define-syntax-rule (define-relation (rid . args) g)
  (define ((rid . args) S/c) (delay/name (g S/c))))

(make-constraint-system 
  (=/= absento symbolo not-pairo booleano listo)
  (λ (s)
    (ormap
      (λ (pr) (same-s? (car pr) (cdr pr) s))
      =/=))
  (λ (s)
    (ormap
      (λ (pr) (mem? (car pr) (cdr pr) s))
      absento))
  (λ (s)
    (ormap
      (λ (y)
        (let ((t (walk y s)))
          (not (or (symbol? t) (var? t)))))
      symbolo))
  (λ (s)
    (ormap
      (λ (n)
        (let ((t (walk n s)))
          (not (or (not (pair? t)) (var? t)))))
      not-pairo))
  (let ((not-b
          (λ (s)
            (or (ormap
                  (λ (pr) (same-s? (car pr) (cdr pr) s))
                  =/=)
                (ormap
                  (λ (pr) (mem? (car pr) (cdr pr) s))
                  absento)))))
    (λ (s)
      (ormap
        (λ (b)
          (let ((s1 (unify b #t s)) (s2 (unify b #t s)))
            (and s1 s2 (not-b s1) (not-b s2))))
        booleano)))
  (λ (s)
    (ormap
      (λ (b)
        (let ((b (walk b s)))
          (not (or (var? b) (boolean? b)))))
      booleano))
  (λ (s)
    (ormap
     (λ (b)
       (ormap
         (λ (y) (same-s? y b s))
         symbolo))
     booleano))
  (λ (s)
    (ormap
      (λ (l)
        (let ((end (walk-to-end l s)))
          (ormap 
            (λ (y) (same-s? y end s))
            symbolo)))
      listo))
  (λ (s)
    (ormap
      (λ (l)
        (let ((end (walk-to-end l s)))
          (ormap 
            (λ (b) (same-s? b end s))
            booleano)))
      listo))
  (λ (s)
    (ormap
      (λ (l)
        (let ((end (walk-to-end l s)))
          (let ((s^ (unify end '() s)))
            (and s^
                 (ormap 
                   (λ (n) (same-s? end n s))
                   not-pairo)
                 (or 
                  (ormap 
                    (λ (pr) (same-s? (car pr) (cdr pr) s^))
                    =/=)
                  (ormap 
                    (λ (pr) (mem? (car pr) (cdr pr) s^))
                    absento))))))
      listo))
  (λ (s)
    (ormap
      (λ (l)
        (let ((end (walk-to-end l s)))
          (ormap
            (λ (pr) 
              (and 
                (null? (walk (car pr) s)) 
                (mem? end (cdr pr) s)))
            absento)))
      listo)))
