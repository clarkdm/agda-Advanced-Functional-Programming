module Ex3 where  -- Conor: 5.5/15 (marked in sem 1 for 3.1-3.4)
                  -- really 5.5/7 then another 3/8 in sem 2, giving 8.5/15

----------------------------------------------------------------------------
-- EXERCISE 3 -- MONADS FOR HUTTON'S RAZOR
--
-- VALUE:     15%
-- DEADLINE:  5pm, Friday 20 November (week 9)
--
-- DON'T SUBMIT, COMMIT!
--
-- The purpose of this exercise is to introduce you to some useful
-- mathematical structures and build good tools for working with
-- vectors
----------------------------------------------------------------------------

open import CS410-Prelude
open import CS410-Monoid
open import CS410-Nat
open import CS410-Vec
open import CS410-Functor

-- HINT: your tasks are heralded with the eminently searchable tag, "???"

----------------------------------------------------------------------------
-- HUTTON'S RAZOR
----------------------------------------------------------------------------

HVal : Set   -- the set of *values* for Hutton's Razor
HVal = Two + Nat   -- Booleans or natural numbers

data HExp (X : Set) : Set where
  var        : X -> HExp X                  -- variables
  val        : HVal -> HExp X               -- values
  _+H_ _>=H_ : (e1 e2 : HExp X) -> HExp X   -- addition, comparison
  ifH_then_else_ : (e1 e2 e3 : HExp X) -> HExp X  -- conditional

_>=2_ : Nat -> Nat -> Two
x      >=2  zero   = tt
zero   >=2  suc _  = ff
suc m  >=2  suc n  = m >=2 n


----------------------------------------------------------------------------
-- ??? 3.1 the HExp syntax-with-substitution monad            (score: 2 / 2)
----------------------------------------------------------------------------

-- Show that HExp is a monad, where the "bind" operation performs
-- simultaneous substitution (transforming all the variables in a term).

hExpMonad : Monad HExp
hExpMonad = record { return = λ x → var x
                   ; _>>=_ = λ x f → hExpMonad>>= x f  
                   ; law1 = λ x f → refl 
                   ; law2 = λ t → hExpMonadLaw2 t  
                   ; law3 = λ f g t → hExpMonadLaw3 t g f  
                   } where


  hExpMonad>>= : {X Y : Set} → HExp X → (X → HExp Y) → HExp Y
  hExpMonad>>= (var x) f = f x
  hExpMonad>>= (val x) f = val x
  hExpMonad>>= (x +H y) f = hExpMonad>>= x f +H hExpMonad>>= y f
  hExpMonad>>= (x >=H y) f = hExpMonad>>= x f >=H  hExpMonad>>= y f 
  hExpMonad>>= (ifH x then y else z) f = ifH hExpMonad>>= x f then 
               hExpMonad>>= y f else hExpMonad>>= z f


  hExpMonadLaw2 : {X : Set} → (t : HExp X) →  hExpMonad>>= t (λ x → var x) == t
  hExpMonadLaw2 (var x) = refl
  hExpMonadLaw2 (val x) = refl
  hExpMonadLaw2 (x +H y) rewrite hExpMonadLaw2 x | hExpMonadLaw2 y  = refl 
  hExpMonadLaw2 (x >=H y) rewrite hExpMonadLaw2 x | hExpMonadLaw2 y  = refl
  hExpMonadLaw2 (ifH x then y else z) rewrite hExpMonadLaw2 x | hExpMonadLaw2 y | hExpMonadLaw2 z = refl

  hExpMonadLaw3 : {X Y Z : Set} →  (t  : HExp X) → (g  : Y → HExp Z) → (f  : X → HExp Y) → hExpMonad>>= (hExpMonad>>= t f) g == hExpMonad>>= t (λ x → hExpMonad>>= (f x) g)
  hExpMonadLaw3 (var x) g t = refl
  hExpMonadLaw3 (val x) g t = refl
  hExpMonadLaw3 (f +H f₁) g t rewrite hExpMonadLaw3 f g t | hExpMonadLaw3 f₁ g t = refl
  hExpMonadLaw3 (f >=H f₁) g t rewrite hExpMonadLaw3 f g t | hExpMonadLaw3 f₁ g t = refl
  hExpMonadLaw3 (ifH f then f₁ else f₂) g t rewrite hExpMonadLaw3 f g t | hExpMonadLaw3 f₁ g t | hExpMonadLaw3 f₂ g t = refl

----------------------------------------------------------------------------
-- ??? 3.2 the error management monad                         (score: 1 / 1)
----------------------------------------------------------------------------

-- show that "+ E" is monadic, generalising the "Maybe" monad by allowing
-- some sort of error report

errorMonad : (E : Set) -> Monad \ V -> V + E   -- "value or error"
errorMonad E = record { return = λ x → tt , x
                      ; _>>=_ = errorMonad>>= 
                      ; law1 = λ x f → refl 
                      ; law2 = errorMonadLaw2 
                      ; law3 = errorMonadLaw3 
                      } where

  errorMonad>>= : {X Y : Set} → X + E → (X → Y + E) → Y + E
  errorMonad>>= (tt , snd) y = y snd
  errorMonad>>= (ff , snd) y = ff , snd

  errorMonadLaw2 : {X : Set} (t : X + E) → errorMonad>>= t (λ x → tt , x) == t 
  errorMonadLaw2 (tt , snd) = refl
  errorMonadLaw2 (ff , snd) = refl

  errorMonadLaw3 :  {X Y Z : Set} (f : X → Y + E) (g : Y → Z + E) (t : X + E) →
                     errorMonad>>= (errorMonad>>= t f) g == errorMonad>>= t 
                    (λ x → errorMonad>>= (f x) g)
  errorMonadLaw3 f g (tt , snd) = refl
  errorMonadLaw3 f g (ff , snd) = refl

----------------------------------------------------------------------------
-- ??? 3.3 the environment monad transformer                   (score: 1 / 1)
----------------------------------------------------------------------------

-- show that any monad can be adapted to thread some environment information
-- as well as whatever else it already managed

envMonad : (G : Set){M : Set -> Set} -> Monad M ->
           Monad \ V -> G -> M V      -- "computation in an environment"
envMonad G {M} MM = record { return = λ {X} z _ → Monad.return MM z 
                       ; _>>=_ = λ {X} {Y} z z₁ z₂ → (MM Monad.>>= z z₂) 
                                   (λ z₃ → z₁ z₃ z₂) 
                       ; law1 = λ {X Y} x f → envMonadLaw1 f x 
                       ; law2 = envMonadLaw2 
                       ; law3 = envMonadLaw3 
                       } where 
  open Monad MM
  
  envMonadLaw1 : {X Y : Set} (f  : X → G → M Y) -> (x  : X) -> 
                 (λ z₂ → return x >>= (λ z₃ → f z₃ z₂)) == f x
  envMonadLaw1 f x = ext (λ g → Monad.law1 MM x (λ z → f z g))
  
  envMonadLaw2 : {X : Set} (t : G → M X) → 
                 (λ z₂ → t z₂ >>= (λ z₃ → return z₃)) == t
  envMonadLaw2 x = ext (λ a → Monad.law2 MM (x a)) 
  
  envMonadLaw3 : {X Y Z : Set} (f : X → G → M Y) (g : Y → G → M Z) (t : G → M X) →(λ z₂ → (t z₂ >>= (λ z₃ → f z₃ z₂)) >>= (λ z₃ → g z₃ z₂)) == (λ z₂ → t z₂ >>= (λ z₃ → f z₃ z₂ >>= (λ z₄ → g z₄ z₂)))
  envMonadLaw3 f g t = ext (λ a → Monad.law3 MM (λ z → f z a) (λ z → g z a) (t a)) 
----------------------------------------------------------------------------
-- ??? 3.4 interpreting Hutton's Razor                        (score: 1.5 / 3)
----------------------------------------------------------------------------

-- Implement an interpreter for Hutton's Razor.
-- You will need to construct a type to represent possible run-time errors.
-- Ensure that addition and comparison act on numbers, not Booleans.
-- Ensure that the condition in an "if" is a Boolean, not a number.

data InterpretError : Set where
  NotTwo               : InterpretError
  NotNat               : InterpretError
  


-- helpful things to build

Env : Set -> Set    -- an environment for a given set of variables
Env X = X -> HVal

Compute : Set{- variables -} -> Set{- values -} -> Set
Compute X V = Env X -> V + InterpretError  -- how to compute a V

computeMonad : {Z : Set} -> Monad (Compute Z)
computeMonad {Z} = envMonad (Env Z) (errorMonad InterpretError)  

 -- build this from the above parts

-- This operation should explain how to get the value of a variable
-- from the environment.
varVal : {X : Set} -> X -> Compute X HVal
varVal x y = tt , (y x)
--  tt , (y x)

-- These operations should ensure that you get the sort of value
-- that you want, in order to ensure that you don't do bogus
-- computation.
mustBeNat : {X : Set} -> HVal -> Compute X Nat
mustBeNat (tt , tt) x = ff , NotNat        -- Conor: more case analysis than needed
mustBeNat (tt , ff) x = ff , NotNat
mustBeNat (ff , zero) x = tt , zero        -- Conor: more case analysis than needed
mustBeNat (ff , suc snd) x = tt , suc snd

mustBeTwo : {X : Set} -> HVal -> Compute X Two
mustBeTwo (tt , tt) x = tt , tt            -- Conor: more case analysis than needed
mustBeTwo (tt , ff) x = tt , ff
mustBeTwo (ff , zero) x = ff , NotTwo     -- Conor: more case analysis than needed
mustBeTwo (ff , suc snd) x = ff , NotTwo

-- Now, you're ready to go. Don't introduce the environment explicitly.
-- Use the monad to thread it.

interpret : {X : Set} -> HExp X -> Compute X HVal
interpret {X} = go where
  open Monad (computeMonad {X})
  go : HExp X -> Compute X HVal
  -- Conor: you already have the right kit, so it's counterproductive to go down to this detail
  go (var x) E = tt , (E x)
  -- Conor: go (var x) = varVal x
  go (val x) E = tt , x
  go (t +H t₁) E = {!!}
  -- Conor: go (l +H r) =
  --   go l >>= \ lv ->               -- lv : HVal
  --   mustBeNat lv >>= \ ln ->       -- ln : Nat
  --   go r >>= \ rv ->               -- rv : HVal
  --   mustBeNat rv >>= \ rn ->       -- rn : Nat
  --   return (ln +N rn)
  go (t >=H t₁) E = {!!}
  go (ifH t then t₁ else t₂) E = {!!}
----------------------------------------------------------------------------
-- ??? 3.5 Typed Hutton's Razor                               (score: 0.5 / 1)
----------------------------------------------------------------------------

-- Labelling the expressions with their types gives strong guarantees
-- sooner (we can make it grammatically incorrect to add a bool to a
-- nat) and makes some things easier as (if we're adding them then we
-- know they are nats).

-- some names for the types we will use in our typed syntax.

data HType : Set where hTwo hNat : HType

-- mapping names for types to real types.

THVal : HType -> Set
THVal hTwo = Two
THVal hNat = Nat

-- A syntax for types expressions, indexed by typed variables. Compare
-- with the untyped HExp and fill in the missing expression formers,
-- we have shown you the way with _+H_. think: what can be guaranteed?

data THExp (X : HType -> Set) : HType -> Set where
  var : forall {T} -> X T -> THExp X T
  val : forall {T} -> THVal T -> THExp X T
  _+H_ : THExp X hNat -> THExp X hNat -> THExp X hNat
  _>=H_ :  THExp X hNat -> THExp X  hTwo {- Conor: hNat here! -} -> THExp X hTwo
  ifH_then_else_ : forall {T} -> THExp X hTwo -> THExp X T -> THExp X T -> THExp X T 

  -- ??? fill in the other two constructs, typed appropriately
  -- (remember that "if then else" can compute values at any type)


----------------------------------------------------------------------------
-- ??? 3.6 Well Typed Programs Don't Go Wrong                 (score: 0 / 1)
----------------------------------------------------------------------------

-- notation for functions betweeen indexed sets (e.g. indexed by types)

_-:>_ : {I : Set}(S T : I -> Set) -> I -> Set
(S -:> T) i = S i -> T i
infixr 3 _-:>_

-- notation for indexed sets

[_] : {I : Set}(X : I -> Set) -> Set
[ X ] = forall {i} -> X i

-- We can put the two together to make types like
--    [ S -:> T ]
--  = forall {i} -> S i -> T i
-- which is the type of functions which work at any index
-- and respect that index. That'll be very useful in just a moment.

-- An evaluator for typed terms, it takes an environment for
-- variables (a function mapping variables to values) and a expression
-- and returns a value). Written as below it looks like it lifts a
-- function from variables to values to a function from terms to
-- values.

eval : {X : HType -> Set} -> [ X -:> THVal ] -> [ THExp X -:> THVal ]
eval g (var x) = g x
eval g (val x) = x
eval g (t +H t1) = eval g t +N eval g t
eval g (t >=H t1) = eval g t >=2 eval g t
eval g (ifH t then t1 else t2) = if eval g t then eval g t1 else eval g t1
  -- Conor: all three step cases get the wrong answers


-- Note that the environment is an *index-respecting* function from
-- variables to values. The index is the type of the variable: you're
-- making sure that when you look up a variable of a given type, you
-- get a value of that type. As a result, you can deliver a *type-safe*
-- evaluator: when an expression has a given type, its value must have
-- that type.


----------------------------------------------------------------------------
-- ??? 3.7 Variable Contexts                                  (score: 1 / 1)
----------------------------------------------------------------------------

-- backwards lists.

data Bwd (X : Set) : Set where
  []   : Bwd X
  _/_  : Bwd X -> X -> Bwd X

-- Our datatype for type indexed expressions is very liberal about
-- variables, they can be any set indexed by types. Here we build
-- something more structured, that nevertheless satisfies the specification

-- We will not use names for variables only numbers.

-- Hence, a context is just a list of types.

Context : Set
Context = Bwd HType

-- Well scoped and well typed variables, top = 0, pop = suc.
-- top is the variable on the right hand end of a non-empty context.
-- pop takes a variable and extends puts it into a longer context.

data Var : (G : Context)(T : HType) -> Set where
  top : {G : Context}{T : HType} -> Var (G / T) T
  pop : {G : Context}{T S : HType} -> Var G T -> Var (G / S) T

-- We can also represent environments as stacks, as opposed to functions.
-- You can read a variable as the sequence of instructions for extracting
-- a value from a stack: you keep popping stuff off until the value you
-- want is the the one at the top.

Stack : Context -> Set
Stack [] = One
Stack (G / S) = Stack G * THVal S

-- Looking up a value for a variable in an an environment or fetching
-- something from a stack given a sequence of pop and top
-- instructions. It's all the same to us!

fetch : {G : Context} -> Stack G -> [ Var G -:> THVal ]
fetch g top = snd g
fetch g (pop v) = fetch (fst g) v

-- An evaluator for expression with more structured variables. We
-- already know how to evaluate, we just have to explain how to deal
-- with manage the different style of environment.

evalStack : {G : Context}{T : HType} ->
            Stack G -> [ THExp (Var G) -:> THVal ]
evalStack g = eval (fetch g)


----------------------------------------------------------------------------
-- ??? 3.8 Terms-With-One-Hole                                (score: 1 / 1)
----------------------------------------------------------------------------

-- Next, we build some kit that we'll use to present type errors.

-- Here we represent an expression with a bit missing. Addition can have
-- have a bit missing (a hole) on the right or on the left. What about
-- the other expression formers?

data HExp' (X : Set) : Set where
  []+H_ _+H[] : HExp X -> HExp' X
  []>=H_ _>=H[] :  HExp X -> HExp' X
  ifH[]then_else_ ifH_then[]else_ ifH_then_else[] : HExp X -> HExp X -> HExp' X

  -- ??? more constructors here
  -- specifically, you will need a constructor for each way that a
  -- subexpression can fit inside an expression;
  -- we use the naming convention of showing where the "hole" is
  -- by putting [] in the corresponding place in the name.

-- take a expression with a hole, and a expression to plug in and plug
-- it in!
_[]<-_ : forall {X} -> HExp' X -> HExp X -> HExp X
([]+H r) []<- t = t +H r
(l +H[]) []<- t = l +H t
([]>=H r) []<- t = t >=H r
(l >=H[]) []<- t = l >=H t
(ifH[]then l else r) []<- t = ifH t then l else r 
(ifH e then[]else r) []<- t = ifH e then t else r
(ifH e then l else[]) []<- t = ifH e then l else t
-- ??? more cases here

{-
data List (X : Set) : Set where  -- X scopes over the whole declaration...
  []    : List X                 -- ...so you can use it here...
  _::_  : X -> List X -> List X  -- ...and here.
infixr 3 _::_
-}
-- As we descend down into a term we can keep the pieces we pass along
-- the way in a list, this is a zipper. For example, given the
-- expression 3 + (4 + 5) we could go down by going right and right
-- again to reach 5. In our list we would have [ 4 + [] , 3 + [] ].

-- we need an operation that takes us back up to the root of the tree,
-- restoring the expression to its former state (e.g. 3 + (4 + 5)).

rootToHole : forall {X} -> List (HExp' X) -> HExp X -> HExp X
rootToHole [] t = t
rootToHole (t' :: t's) t = t' []<- rootToHole t's t

-- The idea is that the pair of a List (HExp' X) and a single
-- HExp X together represent a term with a designated subterm "in focus".
-- The list of one-hole terms represents the *path* to the designated
-- subterm, together with the *other stuff* hanging off to either side
-- of that path.


----------------------------------------------------------------------------
-- ??? 3.9 Forgetting Types                                   (score: 0.5 / 1)
----------------------------------------------------------------------------

-- SUSPICION: why would we want to?

-- Given a typed term (THEXP X T) we can forget the types to obtain an
-- untyped term (HExp Y) if we know how to forget types from variables
-- (varFog).

termFog : {X : HType -> Set}{Y : Set}(varFog : {T : HType} -> X T -> Y) ->
          {T : HType} -> THExp X T -> HExp Y
termFog vF (var x) = var (vF x)
termFog vF (val x) = {!x!}  -- Conor: need to find the type
termFog vF (t +H t1) = (termFog vF t) +H (termFog vF t1)
termFog vF (t >=H t1) = (termFog vF t) >=H (termFog vF t1)
termFog vF (ifH t then t1 else t2) = ifH (termFog vF t) then (termFog vF t1) else (termFog vF t2)

-- Note that it's a local naming convention to call functions which
-- forget information "fog". When it is foggy, you can see less.

-- Our purpose in writing a function to throw away information is to
-- *specify* what it means to *obtain* information.


----------------------------------------------------------------------------
-- ??? 3.10 A Typechecking View                               (score: 0 / 3)
----------------------------------------------------------------------------

-- We finish by building a typechecker which will allow us to detect
-- when an untyped Hutton's Razor term can be converted into a typed
-- term (and evaluated safely without rechecking). We make use of
-- your solution to part 3.9 to express the idea that
--    an untyped term is the forgetful image of a typed term we know
-- and your solution to part 3.8 to express the idea that
--    an untyped term can be focused at a place where there is a type error

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
-- But first, we need to build you a wee bit more kit. Typechecking relies
-- on checking that the type you want is the type you've got, which sometimes
-- means testing *equality* of types. It's not enough to have a function
--   htypeEq : HType -> HType -> Two
-- because we need to convince *Agda* of the equality, not just write a function
-- that happens to say yes to equal things.

-- a set with one element removed, i.e. X -[ x ] is the pair of some y in X and
-- a proof that y isn't x

_-[_] : (X : Set) -> X -> Set
X -[ x ] = Sg X \ y -> x == y -> Zero

-- a view for comparing types for equality

data HTypeComparable (T : HType) : HType -> Set where
  same : HTypeComparable T T
  diff : (SnT : HType -[ T ]) -> HTypeComparable T (fst SnT)

-- the above view type presents is two options, and in both of them, we
-- have to come through with enough evidence to convince Agda

-- implementing the view

hTypeCompare : (S T : HType) -> HTypeComparable S T
hTypeCompare hTwo hTwo = same
hTypeCompare hTwo hNat = diff (hNat , \ ())
hTypeCompare hNat hTwo = diff (hTwo , \ ())
hTypeCompare hNat hNat = same

-- we write the obvious four cases; in the "same" cases, the types really
-- do match; in the "diff" cases, Agda can rule out the equation hTwo == hNat
-- (or vice versa) because it knows the constructors of datatypes differ
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

-- But back to our typechecker. To make things easier, we'll assume
-- that our supplier has already been kind enough to do *scope* checking,
-- so that all the variables written by the programmer have been looked
-- up and turned into typed references.

-- a reference: a pair of a type and a variable of that type.

Ref : Context -> Set
Ref G = Sg HType (Var G)

-- making a reference

ref : forall {G S} -> Var G S -> Ref G
ref {G}{S} v = S , v

-- ??? At last, your bit! Show that the following view type covers all
-- untyped terms:
--   either things go well and get the 'ok' and a well typed term
--   or something went wrong down in the expression tree somewhere,
--     so we can explain where that is.

data Checkable (G : Context)  -- the context of typed variables in scope
               (T : HType)    -- the type we expect
               :
               HExp (Ref G)   -- the untyped term we hope has type T
               -> Set where   -- one of two situations applies
  -- either
  ok    : (t : THExp (Var G) T)              -- we have a term of type T
          -> Checkable G T (termFog ref t)   -- and it's what we're checking
  -- or
  err   : (t's : List (HExp' (Ref G)))  -- there's some surroundings
          (s : HExp (Ref G))            -- and a subterm of interest
          -> Checkable G T (rootToHole t's s)  -- in what we're checking

check : (G : Context)(T : HType)(h : HExp (Ref G)) -> Checkable G T h
check G T h = {!!}

-- Now, this isn't quite the whole story, but it's pretty good. We've
-- guaranteed that
--   * if we say yes, it's because we've found the typed version
--     of the untyped input
--   * if we say no, we can point to a place where (we say that) there's a
--     problem
-- So we're *sound* (we never say yes to bad things), but not necessarily
-- *complete* (we can say no to good things). Nothing stops us reporting a
-- bogus type error at the subterm of our choosing! We could work harder
-- and define, in the same way as the typed terms, the "terrors", being
-- the terms containing at least one type error. The canny way to do that
-- is to try writing the typechecker, then grow the datatype that describes
-- all the failure cases.

------------------------------------------------------------------------------
--
-- If you want to read around this topic, you may be interested in
--
--   The Zipper
--   Gerard Huet
--   Journal of Functional Programming, 1997.
--
--   Monadic presentations of lambda terms using generalized inductive types
--   Thorsten Altenkirch and Bernhard Reus
--   Computer Science Logic, 1999.
--
--   An exercise in dependent types: A well-typed interpreter
--   Lennart Augustsson and Magnus Carlsson
--   Workshop on Dependent Types in Programming, Gothenburg, 1999.
--
--   The view from the left
--   Conor McBride and James McKinna
--   Journal of Functional Programming, 2004.
