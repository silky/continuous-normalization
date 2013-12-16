{-# OPTIONS --copatterns --sized-types #-}

module LocallyNameless.Eval where

open import Library
open import Term
open import Delay
open import Spine
open import DBLevel
open import LocallyNameless.Values

-- Lifting.

var0 : ∀ {Δ a} → Val (Δ , a) a
var0 = ne (newLvl _) ε

liftEnv : ∀ {Γ Δ a} → Env Δ Γ → Env (Δ , a) (Γ , a)
liftEnv {Δ = Δ} ρ = weakEnv ρ , var0

-- Call-by-value evaluation.

mutual
  〖_〗  : ∀ {i} {Γ : Cxt} {a : Ty} → Tm Γ a → {Δ : Cxt} → Env Δ Γ → Delay (Val Δ a) i
  〖 var x   〗 ρ = now (lookup x ρ)
  〖 abs t   〗 ρ = now (lam t ρ)
  〖 app t u 〗 ρ = apply* (〖 t 〗 ρ) (〖 u 〗 ρ)

  apply* : ∀ {i Δ a b} → Delay (Val Δ (a ⇒ b)) i → Delay (Val Δ a) i → Delay (Val Δ b) i
  apply* f⊥ v⊥ = apply =<<2 f⊥ , v⊥

  apply : ∀ {i Δ a b} → Val Δ (a ⇒ b) → Val Δ a → Delay (Val Δ b) i
  apply f v = later (∞apply f v)

  ∞apply : ∀ {i Δ a b} → Val Δ (a ⇒ b) → Val Δ a → ∞Delay (Val Δ b) i
  force (∞apply (lam t ρ) v) = 〖 t 〗 (ρ , v)
  force (∞apply (ne x sp) v) = now (ne x (sp , v))

-- β-quoting

mutual
  β-readback : ∀{i Γ a} → Val Γ a → Delay (βNf Γ a) i
  β-readback v = later (∞β-readback v)

  ∞β-readback : ∀{i Γ a} → Val Γ a → ∞Delay (βNf Γ a) i
  force (∞β-readback (lam t ρ)) = lam  <$> (β-readback =<< 〖 t 〗 (liftEnv ρ))
  force (∞β-readback (ne x rs)) = ne (ind x) <$> mapRSpM β-readback rs

-- βη-quoting

mutual

  readback : ∀{i j Γ a} → Val {j} Γ a → Delay (Nf Γ a) i
  readback {a = ★} (ne x vs) = ne (ind x) <$> readbackSpine vs
  readback {a = b ⇒ c}     v = later (∞readback v)

  ∞readback : ∀{i Γ b c} → Val Γ (b ⇒ c) → ∞Delay (Nf Γ (b ⇒ c)) i
  force (∞readback v) = lam <$> (readback =<< apply (weakVal v) var0)

  readbackSpine : ∀{i j Γ a c} → ValSpine {j} Γ a c → Delay (NfSpine Γ a c) i
  readbackSpine = mapRSpM readback

------------------------------------------------------------------------

-- Congruence fore eval/apply

~apply* : ∀ {Δ a b} {f1? f2? : Delay (Val Δ (a ⇒ b)) ∞} {u1? u2? : Delay (Val Δ a) ∞} →
  (eqf : f1? ~ f2?) (equ : u1? ~ u2?) → apply* f1? u1? ~ apply* f2? u2?
~apply* eqf equ = eqf ~>>= λ f → equ ~>>= λ u → ~refl _

-- Monotonicity for eval/apply

mutual

  eval≤ : ∀ {Γ Δ Δ' a} (t : Tm Γ a) (ρ : Env Δ Γ) (η : Δ' ≤ Δ) →
    (val≤ η <$> (〖 t 〗 ρ)) ~ 〖 t 〗 (env≤ η ρ)
  eval≤ (var x  ) ρ η rewrite lookup≤ x ρ η = ~now _
  eval≤ (abs t  ) ρ η = ~refl _
  eval≤ (app t u) ρ η = begin

      (val≤ η <$> apply* (〖 t 〗 ρ) (〖 u 〗 ρ))

    ~⟨ apply*≤ (〖 t 〗 ρ) (〖 u 〗 ρ) η ⟩

      apply* (val≤ η <$> 〖 t 〗 ρ) (val≤ η <$> 〖 u 〗 ρ)

    ~⟨ ~apply* (eval≤ t ρ η) (eval≤ u ρ η) ⟩

      apply* (〖 t 〗 (env≤ η ρ)) (〖 u 〗 (env≤ η ρ))

    ∎ where open ~-Reasoning

  apply*≤ : ∀ {Γ Δ a b} (f? : Delay (Val Δ (a ⇒ b)) ∞) (u? : Delay (Val Δ a) ∞) (η : Γ ≤ Δ) →
    (val≤ η <$> apply* f? u?) ~ apply* (val≤ η <$> f?) (val≤ η <$> u?)
  apply*≤ f? u? η = begin

      val≤ η <$> apply* f? u?

    ≡⟨⟩

      val≤ η <$> apply =<<2 f? , u?

    ≡⟨⟩

      val≤ η <$> (f? >>= λ f → u? >>= apply f)

    ≡⟨⟩

      ((f? >>= (λ f → u? >>= apply f)) >>= λ v → return (val≤ η v))

    ~⟨ bind-assoc f? ⟩

      (f? >>= λ f → (u? >>= apply f) >>= λ v → return (val≤ η v))

    ~⟨ (f? >>=r λ f → bind-assoc u?) ⟩

      (f? >>= λ f → u? >>= λ u → apply f u >>= λ v → return (val≤ η v))

    ≡⟨⟩

      (f? >>= λ f → u? >>= λ u → val≤ η <$> apply f u)

    ~⟨ (f? >>=r λ f → u? >>=r λ u → apply≤ f u η) ⟩

      (f? >>= λ f → u? >>= λ u → apply (val≤ η f) (val≤ η u))

    ~⟨ ~sym (bind-assoc f?)  ⟩

      ((f? >>= λ f → return (val≤ η f)) >>= λ f' → u? >>= λ u → apply f' (val≤ η u))

    ≡⟨⟩

      ((val≤ η <$> f?) >>= λ f' → u? >>= λ u → apply f' (val≤ η u))

    ~⟨ ((val≤ η <$> f?) >>=r λ f' → ~sym (bind-assoc u?)) ⟩

      ((val≤ η <$> f?) >>= λ f' → (u? >>= λ u → return (val≤ η u)) >>= λ u' → apply f' u')

    ≡⟨⟩

      ((val≤ η <$> f?) >>= λ f' → (val≤ η <$> u?) >>= λ u' → apply f' u')

    ≡⟨⟩

      apply =<<2 (val≤ η <$> f?) , (val≤ η <$> u?)

    ≡⟨⟩

      apply* (val≤ η <$> f?) (val≤ η <$> u?)

    ∎ where open ~-Reasoning

  apply≤ : ∀ {Γ Δ a b} (f : Val {∞} Δ (a ⇒ b)) (v : Val {∞} Δ a) (η : Γ ≤ Δ) →
    (val≤ η <$> apply f v) ~ apply (val≤ η f) (val≤ η v)
  apply≤ f v η = ~later (∞apply≤ f v η)

  ∞apply≤ : ∀ {Γ Δ a b} (f : Val {∞} Δ (a ⇒ b)) (v : Val {∞} Δ a) (η : Γ ≤ Δ) →
    (val≤ η ∞<$> ∞apply f v) ∞~ ∞apply (val≤ η f) (val≤ η v)
  ∞apply≤ f v η = {!!}
