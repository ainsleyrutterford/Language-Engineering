import Control.Applicative

---------------
-- LECTURE 1 --
---------------

-- The goal of these lectures is to understand the design and construction
-- of programming languages.

-- The course is split into two parts:
-- TB1: LANGUAGE DESIGN
-- TB2: SEMANTICS

-- A DSL can be crafted from the ground up. This includes building many
-- things. An embedded Domain Specific Language reduces all of this
-- infrastructure.

-- Embeddings come in two flavours:

-- Deep embedding: syntax is made up of concrete datatypes. Semantics are
-- assigned by evaluating the syntax.

-- Shallow embedding: syntax is borrowed from the host language. Semantics
-- are directly assigned.

-- Deep embedding example:

data Expr = Val Int
          | Add Expr Expr

eval :: Expr -> Int
eval (Val n) = n
eval (Add x y) = eval x + eval y

-- Example of using this language: eval (Add (Val 3) (Val 5))

-- Shallow embedding example:

val :: Int -> Int
val n = n

add' :: Int -> Int -> Int
add' x y = x+y

-- Example of using this language: add' 3 5
-- or: add' (var 3) (var 5)

---------------
-- LECTURE 2 --
---------------

-- Giving the 'Circuit' language a semantics:

-- Shallow embedding:

type Circuit = Width

type Width = Int

identity :: Int -> Circuit
identity w = w

above :: Circuit -> Circuit -> Circuit
above c1 c2 = c1

beside :: Circuit -> Circuit -> Circuit
beside c1 c2 = c1 + c2

fan :: Int -> Circuit
fan w = w

-- Stretch the wires, and connect the last to last.
stretch :: [Int] -> Circuit -> Circuit
stretch ws c = sum ws

-- Example of using this language: above (identity 3) (fan 3)

-- Deep embedding:

-- A deep embedding is achieved in two stages:
-- - Provide a dataytpe for the language
-- - Provide a semantics that evaluates the data

-- The deep embedding preserves all of the structure

data Circuit' = Identity Int
              | Above Circuit' Circuit'
              | Beside Circuit' Circuit'
              | Fan Int
              | Stretch [Int] Circuit'

-- Now we give the semantics:

width :: Circuit' -> Int
width (Identity n) = n
width (Above c1 c2) = width c1
width (Beside c1 c2) = width c1 + width c2
width (Fan n) = n
width (Stretch ws c) = sum ws

-- We might want to give a semantics that is the height of the circuit.

-- Multiple interpretations are easy in deep embeddings, because they
-- correspond to a new evaluation function.

height :: Circuit' -> Int
height (Identity n) = 1
height (Above c1 c2) = height c1 + height c2
height (Beside c1 c2) = height c1
height (Fan w) = 1
height (Stretch ws c) = height c

-- For multiple interpretations in shallow we can use a tuple:

type Circuit'' = (Width,Height) -- Width is an Int as defined before

type Height = Int

identity' :: Int -> Circuit''
identity' w = (w,1)

above' :: Circuit'' -> Circuit'' -> Circuit''
above' (w1,h1) (w2,h2) = (w1, h1+h2)

beside' :: Circuit'' -> Circuit'' -> Circuit''
beside' (w1,h1) (w2,h2) = (w1+w2, h1)

-- Some interpretations have dependencies.

-- For example, we might be interested in how well connected the circuit is.

type Circ = (Bool, Width) -- Width is an Int as defined before

identity'' :: Int -> Circ
identity'' w = (True, w)

above'' :: Circ -> Circ -> Circ
above'' (b1,w1) (b2,w2) = (b1 && b2 && w1 == w2, w1)

beside'' :: Circ -> Circ -> Circ
beside'' (b1,w1) (b2,w2) = (b1 && b2, w1 + w2)

-- And so on...
-- The point here is that we might need to combine information. Doing so
-- involves extending our domain and the definitios everywhere. This is a pain.

---------------
-- LECTURE 3 --
---------------

-- Catamorphisms destroy recursive datatypes to compute values.

-- Consider a recursive definition of lists (without the syntactic sugar)

data List a = Empty | Cons a (List a)

-- This is analogous to []:[a]
-- (:) a -> [a] -> [a]

-- The data definition introduced two functions:

-- Empty :: List a
-- Cons :: a -> List a -> List a

-- The length function is defined as follows:

length' :: List a -> Int
length' (Empty) = 0
length' (Cons a xs) = 1 + length' xs

-- To remove recursion from the List datatype, we introduce an extra paramater.

data ListF a k = EmptyF | ConsF a k -- k stands for kontinuation

-- All the recursion gets moved into the following datatype:

data Fix f = In (f (Fix f))

-- What is f exactly? We need to talk about kinds

-- A kind is the type of a type.

-- The kind of types that are inhabited by values is *.
-- Examples:

-- Int :: *
-- Char :: *
-- Bool :: *
-- Maybe Int :: *
-- List Int :: *

-- The kind of other things can be more complex:

-- Maybe :: * -> *
-- List :: * -> *

-- More erotic:

-- (,) :: * -> * -> *
-- (->) :: * -> * -> *
-- Either :: * -> * -> *

-- Even more erotic is Fix:

-- data Fix f = In (f (Fix f))
-- f :: * -> *
-- Fix :: (* -> *) -> *

-- To retrieve ordinary recursive lists, we can say:
-- List a ~= Fix (ListF a)

-- Notice that ListF a k was defined, but we are not using k in the
-- definition above. Here are some examples of values:

-- Empty ~= In EmptyF

-- List a                       Fix (ListF a)
-- Cons 5 Empty                 In (ConsF 5 (In EmptyF)
-- Cons 3 (Cons 7 Empty)        In (ConsF 3 (In (ConsF 7 (In EmptyF))))

-- We know that:
-- EmptyF :: ListF a k
-- ConsF :: a -> k -> ListF a k

-- ConsF 3 (ConsF 7 EmptyF) :: ListF a (ListF a (ListF a k))
-- The point of Fix was to avoid this telescoping type:
-- In (ConsF 3 (In (ConsF 7 (In EmptyF)))) :: Fix (ListF a)
-- Where In :: f (Fix f) -> Fix f

---------------
-- LECTURE 4 --
---------------

-- The point of all this abstraction is to have a generalised notion of
-- folding over algebraic data types, such as lists and trees.

-- To recap, foldr is the following:

foldr' :: (a -> b -> b) -> b -> [a] -> b
foldr' f k [] = k
foldr' f k (x:xs) = f x (foldr' f k xs)

-- How does the structure of foldr relate to the constructors of lists?

-- [] : [a]                        k :: b
-- (:) :: a -> [a] -> [a]          f :: a -> b -> b

-- It turns out, that all we need to do is replace instances of [a] with b.

-- Using ListF, we might be interested in functions of the following form,
-- which are technically called algebras:

-- alg :: ListF a b -> b
-- alg EmptyF = k
-- alg (ConsF x xs) = f x xs

-- Catamorphisms are the generalisation of folds. The following diagram
-- captures the essence of catamorphisms:

--            fmap (cata alg)
-- f (Fix f) -----------------> f b
--  In ↓ ↑ In0                  ↓ alg
--   Fix f -------------------> b
--              cata alg

-- This involves using the function fmap, which comes from the functor instance:
class Functor' f where
  fmap' :: (a -> b) -> (f a -> f b)

-- We also need In0, which is the inverse of In. The existence of In0 is
-- guarenteed by Lambet's Lemma.

---------------
-- LECTURE 5 --
---------------

-- In0 is defined as follows:
in0 :: Fix f -> f (Fix f)
in0 (In x) = x

-- Now we have to give a Functor instance for ListF.

instance Functor' (ListF a) where
  -- fmap :: (a -> b) -> ListF n a -> ListF n b
  fmap' f (EmptyF) = EmptyF
  fmap' f (ConsF n x) = ConsF n (f x)

-- As an example, we will take the length of a list:

length'' :: Fix (ListF a) -> Int
length'' = cata alg where
  alg :: ListF a Int -> Int
  alg EmptyF = 0
  alg (ConsF n x) = 1 + x

-- The definition of cata is:

cata :: Functor' f => (f b -> b) -> Fix f -> b
cata alg = alg . fmap' (cata alg) . in0

-- alternative definition:
cata' :: Functor' f => (f b -> b) -> Fix f -> b
cata' alg (In x) = (alg . fmap' (cata' alg)) x

sum' :: Fix (ListF Int) -> Int
sum' = cata alg where
  alg :: ListF Int Int -> Int
  alg EmptyF = 0
  alg (ConsF n x) = n + x

---------------
-- LECTURE 6 --
---------------

-- It is instinctive to see how we can convert between list representations.

toListF :: [a] -> Fix (ListF a)
toListF = foldr' f k where
  f :: a -> Fix (ListF a) -> Fix (ListF a)
  f x xs = In (ConsF x xs)
  k :: Fix (ListF a)
  k = In EmptyF

-- Remember that foldr 'replaces' (:) with f, and [] with k

-- Now we will do the same thing for fromListF

fromListF :: Fix (ListF a) -> [a]
fromListF = cata alg where
  alg :: ListF a [a] -> [a]
  alg EmptyF = []
  alf (ConsF x xs) = x:xs

-- Peano Numbers:

-- One way of representing numbers is to use the Peano representation. This
-- starts with zero and adds one successively.

data Nat = Z | S Nat

-- Zero ~= zero
-- S ~= successor

-- Example: tp represent 3, we have S (S (S Z))

-- The first step is to write the "patern functor" for Nat.
-- This is:

data NatF k = ZF | SF k

-- We have to provide a functor instance for this:

instance Functor' NatF where
  -- fmap' :: (a -> b) -> NatF a -> NatF b
  fmap' f ZF = ZF
  fmap' f (SF x) = SF (f x)

-- At this point, we have to prove the two functor laws:

-- Law 1. fmap id = id
-- Law 2. fmap g . fmap f = fmap (g . f)

-- Note that we are interested in reducing Fix NatF values. For instance,
-- we might want to interpret as an Int in Haskell.

toInt :: Fix NatF -> Int
toInt = cata alg where
  alg :: NatF Int -> Int
  alg ZF = 0
  alg (SF n) = 1 + n

double :: Fix NatF -> Fix NatF
double = cata alg where
  alg :: NatF (Fix NatF) -> Fix NatF
  alg ZF = In ZF
  alg (SF n) = In (SF (In (SF n)))

power :: Fix NatF -> Fix NatF
power = cata alg where
  alg :: NatF (Fix NatF) -> Fix NatF
  alg ZF = In (SF (In ZF))
  alg (SF n) = double n

---------------
-- LECTURE 7 --
---------------

-- We would like to decompose the syntax and semantics of the Expr example in
-- Lecture 1 into its constituent parts.

-- We do this by providing a functor for each fragment of syntax as follows:

data Val' k = Val' Int

instance Functor Val' where
  -- fmap :: (a -> b) -> Val' a -> Val' b
  fmap f (Val' n) = Val' n

-- NB Be careful to consider which "Val'" is a type, and which is a value.

-- Now we can define another syntactic fragment:

data Add' k = Add' k k

instance Functor Add' where
  -- fmap :: (a -> b) -> Add' a -> Add' b
  fmap f (Add' x y) = Add' (f x) (f y)

-- Conceptually, we have defined two languages.

-- Fix Val' and Fix Add'

-- We would like to combine these two languages into one where we have Add'
-- and Val' working together:

-- :: Fix (Val' :+ Add')
-- But when writing this in haskell I could only get
-- :: Fix (CoProd Val' Add') to work

-- As code, this would be something that combines the syntax in Add' with the
-- syntax in Val'.

-- We introduce the coproduct functor to achieve this:

data CoProd f g k = L (f k)
                  | R (g k)

instance (Functor f, Functor g) => Functor (CoProd f g) where
  fmap f (L x) = L (fmap f x)
  fmap f (R y) = R (fmap f y)

-- An example of syntax of the form Fix (CoProd Val' Add'):

-- In (R (Add' (In (L (Val' 3)))
--             (In (R (Add' (In (L (Val' 4)))
--                          (In (L (Val' 5))))))))

---------------
-- LECTURE 8 --
---------------

-- Combining Semantics

-- Now we show how to combine algebras.

-- We will give a semantics to each sublanguage.

algVal :: Val' Int -> Int
algVal (Val' n) = n

-- The semantic function that evaluates Fix Val' is:
-- cata algVal :: Fix Val' -> Int

-- For the add language we give a different semantics:

algAdd :: Add' Int -> Int
algAdd (Add' x y) = x + y

-- The semantic function for this is:
-- cata algAdd :: Fix Add' -> Int

-- We want a way to combine these algebras to give a semantics to
-- Fix (CoProd Val' Add') trees.

-- \/ = junc

(\/) :: (f a -> a) -> (g a -> a) -> ((CoProd f g) a -> a)
(algF \/ algG) (L x) = algF x
(algF \/ algG) (R y) = algG y

-- To give a semantics to the Fix (CoProd Val' Add') tree, we use a cata
-- as before:

-- cata (junc algVal algAdd) :: Fix (CoProd Val' Add') -> Int

-- This gives us a technique that has all the advantages of shallow and deep
-- embeddings.

---------------
-- LECTURE 9 --
---------------

-- Languages are usually specified in terms of a grammar and grammars are
-- usually given using Backus-Naur Form (BNF). This was introduced for the
-- design of Algol in around 1958.

-- An expression would be given as follows:

-- <expr> ::= <term> | <expr> "+" <term>
-- <term> ::= ('0' | '1' | ... | '9')+

-- This language consists of terminals eg. "+" or '0' or '5' and
-- non-terminals in anled brackets eg. <expr> or <term>

-- BNF consists of:

-- <expr>          non-terminals, which are in the output
-- "3"             terminals, which are in the intput
-- p | q           alternations

-- Equations are introduced using "::="

-- BNF has since been extended to EBNF:

-- [ expr ]        Optionals
-- ( expr )        groupings
-- { expr }        repetition (0 or more)

-- Conventionally we also have:

-- expr+           1 or more expr
-- expr*           0 or more expr

-- Here is a grammar we might want to parse:

-- <expr> ::= <term> ("+" <term>)*
-- <term> ::= ('0' | '1' | ... | '9')+

data Expr' = ExprTerm Term [Term] deriving Show
data Term = Term Int deriving Show

expr :: Parser Expr'
expr = ExprTerm <$> term <*> many (string "+" *> term)

term :: Parser Term
term = Term <$> decimal

oneOf :: [Char] -> Parser Char
oneOf = satisfy . flip elem

decimal :: Parser Int
decimal = (fmap read (some (oneOf "0123456789")))

-- We may test this by executing the following in ghci:
-- parseMaybe expr "1+2+3"

-- Left recursion

-- Some grammers can be defined with left recursion
-- Eg:

-- <expr> ::= <term> | <expr> "+" <expr>
-- <term> ::= '0' | ... | '9'

-- The <expr> before the "+" is the left recursion

----------------
-- LECTURE 10 --
----------------

-- The problem with left recursion is that we can repeatedly seek to make
-- an <expr> without consuming a terminal symbol. This can make an infinite
-- loop.

-- Paull's algorithm

-- Paull's algorithm allows us to restate a grammar so that it contains no
-- more left recursion.

-- Given:

-- A ::= A(a1) | ... | A(an) | B1 | ... | Bm

-- where A is a nonterminal and a1 ... an are other parts of a rule, which may
-- contain A, and B1 ... Bm do not start with A,

-- then we remove left recursion with this grammar:

-- A ::= B1 | B1(A') | ... | Bm | Bm(A')
-- A' ::= (a1) | (a1)A' | ... | (an) | (an)A'

-- where A' is a fresh non-terminal.

-- For example we can apply Paull's algorithm to <expr>:
-- <expr> ::= <term> | <term> <expr'>
-- <expr'> ::= "+" <expr> | "+" <expr> <expr'>

-- The problem which this is that it introduces many common prefixes.

-- Paull's modified algorithm

-- This variation causes fewer common prefixes:

-- Given:

-- A ::= A(a1) | ... | A(an) | B1 | ... | Bm

-- Then:

-- A ::= B1(A') | ... | Bm(A')
-- A' ::= (a1)A' | ... | (an)A' | Empty

-- In our example we would have:

-- <expr> ::= <term> <expr'>
-- <expr'> ::= "+" <expr> <expr'> | Empty

-- Note that <expr'> is very much like a list of "+" <expr> terms: Empty is
-- the empty list and "+" <expr> is repeated.

-- Parsers

-- You might think of a parser as a function:

-- :: String -> a
-- But this is too optimistic: the parser might fail to produce a value of
-- type a.

-- So perhapse this is a parser instead:

-- :: String -> Maybe a
-- However, there may be ambiguitys in the grammar, and these parsers can't
-- return more than one result.

-- :: String -> [a]
-- This parser will parse the whole input, and if not, discards the left over
-- string. The empty list [] captures failure.oneOf = satisfy . flip elem

-- So, the type of a parser is better modelled as:

-- :: String -> [(String, a)]
-- String is the input string.
-- the String in the tuple is the remaining string.
-- the a in the tuple is the output value.

-- Our task is to build a library of small parsers, and we will start with
-- the simplest.

-- The simples parser is arguably "produce" which always finds the output you
-- give it, and doesn't consume any input.

produce' :: a -> String -> [(String, a)]
produce' x ts = [(ts, x)]

-- It will be tedious to write String -> [(String, a)] everywhere, so we
-- make a new type:

newtype Parser a = Parser (String -> [(String, a)])

-- To parse with a Parser a, we need a parse function.

parse :: Parser a -> String -> [(String, a)]
parse (Parser px) = px
-- parse (Parser px) ts = px ts

-- Another parser is fail, which never succeeds...

fail' :: Parser a
fail' = Parser (\ts -> [])

-- We can give a similar style definition of produce:

produce :: a -> Parser a
produce x = Parser (\ts -> [(ts, x)])

----------------
-- LECTURE 11 --
----------------

-- ITEM

-- The item parser tells you what the next item is:

item :: Parser Char
item = Parser (\ts -> case ts of
  []     -> []
  (t:ts) -> [(ts,t)])

-- From here, we will go up the hierarchy, and produce parsers that are
-- Functors, Applicatives, Alternatives and Monads.

-- Functor

-- A parser that returns something of type 'a', can be told to return a 'b'
-- instead if you give it a function f :: a -> b.

instance Functor Parser where
  fmap f (Parser px) = Parser (\ts -> [(ts', f x) | (ts', x) <- px ts])

-- In our parser library, we use <$>, but this is precisely fmap:

-- Ive used <|$|> because <$> is already defined.
(<|$|>) :: Functor f => (a -> b) -> f a -> f b
f <|$|> x = fmap f x

-- Sometimes, we want to parse, but not use the function because it is a
-- constant.

-- I've used <|$ becayse <$ is already defined.
(<|$) :: Functor f => a -> f b -> f a
(<|$) = fmap . const

-- To understand this, consider it fully applied:
-- x <$ py = (fmap . const) x py
--         = fmap (const x) py

-- The function const is defined:
-- const :: a -> b -> a
-- const x y = x

-- Applicative

-- Applicatives give a sense of chaining parsers together, where the output
-- of the first parser does not affect the control flow.

instance Applicative Parser where
  -- pure :: a -> Parser a
  pure x = Parser (\ts -> [(ts,x)])
  -- (<*>) :: Parser (a -> b) -> Parser a -> Parser b
  Parser pf <*> Parser px = Parser (\ts ->
    [(ts'', f x) | (ts', f) <- pf ts
                 , (ts'', x) <- px ts'])

----------------
-- LECTURE 12 --
----------------

-- As a quick refresher to list comprehension notation:
-- [(x,y) | x <- [0..2], y <- ['a'..'b']]
-- = [(0,'a'), (0,'b'), (1,'a'), (1,'b'), (2,'a'), (2,'b')]

-- There are some variants of <*>, which are:

-- I've used <|* because <* is already defined.
(<|*) :: Applicative f => f a -> f b -> f a
px <|* py = const <$> px <*> py

(*|>) :: Applicative f => f a -> f b -> f b
px *|> py = flip const <$> px <*> py
  -- where flip :: (a -> b -> c) -> (b -> a -> c)
  --       flip f y x = f x y

(<|**|>) :: Applicative f => f a -> f (a -> b) -> f b
px <|**|> pf = flip ($) <$> px <*> pf
  -- where ($) :: (a -> b) -> a -> b
  --       f $ x = f x

-- For intuition, let's see how (<*) and (*>) work for lists:

-- [1,2,3] <* [4,5,6] = [1,1,1,2,2,2,3,3,3]
-- [1,2,3] *> [4,5,6] = [4,5,6,4,5,6,4,5,6]

-- Alternatives

-- Now we capture the idea that there may be no solution to a parse, or
-- multiple solutions:

instance Alternative Parser where
  -- empty :: Parser a
  empty = Parser (\ts -> [])
  -- (<|>) :: Parser a -> Parser a -> Parser a
  Parser px <|> Parser py = Parser (\ts -> px ts ++ py ts)

-- This is enough for us to generate parsers that correspond to:
-- p+, which is 'some p', and
-- p*, which is 'many p'.

some' :: Alternative f => f a -> f [a]
some' px = px <:> many' px

(<:>) :: Applicative f => f a -> f [a] -> f [a]
x <:> xs = (:) <$> x <*> xs

many' :: Alternative f => f a -> f [a]
many' px = some' px <|> empty

----------------
-- LECTURE 13 --
----------------

-- Monads

-- Monads encapsulate the idea of a sequence of operations.

instance Monad Parser where
  -- return :: a -> Parser a
  return x = produce x -- or pure x
  -- (>>=) :: Parser a -> (a -> Parser b) -> Parser b
  Parser px >>= f = Parser (\ts -> concat [parse (f x) ts' | (ts',x) <- px ts])

-- We can use all the parsers we have defined so far to generate one called
-- satisfy.

satisfy :: (Char -> Bool) -> Parser Char
satisfy p = item >>= \t -> if p t then return t
                                  else empty

-- We can use this to define char:

char :: Char -> Parser Char
char c = satisfy (== c)

-- Finally we can define a parser that checks if a particular string is
-- present:

string :: String -> Parser String
string [] = return ""
string (c:cs) = char c <:> string cs

-- When we are done parsing, we need to make sure that we are at the end
-- of the file:

eof :: Parser ()
eof = Parser (\ts -> case ts of
  [] -> [(ts, ())]
  _  -> [])
