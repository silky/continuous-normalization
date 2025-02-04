module EquationalTheory where

open import Library
open import Syntax
open import RenamingAndSubstitution

-- Single collapsing substitution.

sub1 : ∀{Γ σ τ} → Tm Γ σ → Tm (Γ , σ) τ → Tm Γ τ
sub1 {Γ}{σ}{τ} u t = sub (subId , u) t

-- UNUSED:
data _≡v_ : ∀{Γ σ} → Var Γ σ → Var Γ σ → Set where
  zero : ∀{Γ σ} → zero {Γ}{σ} ≡v zero
  suc  : ∀{Γ σ τ}{x x' : Var Γ σ} → x ≡v x' → suc {b = τ} x ≡v suc x'

data _≡βη_ {Γ : Cxt} : ∀{σ} → Tm Γ σ → Tm Γ σ → Set where
  var≡  : ∀{σ} (x : Var Γ σ) → var x ≡βη var x
  abs≡  : ∀{σ τ}{t t' : Tm (Γ , σ) τ} → t ≡βη t' → abs t ≡βη abs t'
  app≡  : ∀{σ τ}{t t' : Tm Γ (σ ⇒ τ)}{u u' : Tm Γ σ} → t ≡βη t' → u ≡βη u' →
          app t u ≡βη app t' u'
  beta≡ : ∀{σ τ}{t : Tm (Γ , σ) τ}{u : Tm Γ σ} →
          app (abs t) u ≡βη sub (subId , u) t
  eta≡   : ∀{σ τ}(t : Tm Γ (σ ⇒ τ)) →
           abs (app (ren (wkr renId) t) (var zero)) ≡βη t
  refl≡  : ∀{a} (t : Tm Γ a) → t ≡βη t
  sym≡   : ∀{a}{t t' : Tm Γ a}    (t'≡t : t' ≡βη t) → t ≡βη t'
  trans≡ : ∀{a}{t₁ t₂ t₃ : Tm Γ a} (t₁≡t₂ : t₁ ≡βη t₂) (t₂≡t₃ : t₂ ≡βη t₃) → t₁ ≡βη t₃
