module Ditto.Test where
import Ditto.Syntax
import Ditto.Parse
import Ditto.Check
import Ditto.Conv
import Ditto.Whnf
import Test.HUnit

----------------------------------------------------------------------

_Identity = "((A : Type) (a : A) : A)"
identity = "((A : Type) (a : A) = a)"
_PiWh = "((A : Type) : " ++ identity ++ " Type Type)"

idProg = unlines
  [ "def id (A : Type) (a : A) : A where"
  , "(A : Type) (a : A) = a"
  , "end"

  , "def KType : id Type Type where"
  , "id Type ((A : Type) : id Type Type)"
  , "end"

  , "data Nat : Type where "
  , "| zero : Nat"
  , "| suc (n : Nat) : id Type Nat" -- note the not normal type at the end
  , "end"
  ]

dataProg = unlines
  [ "data Nat : Type where "
  , "| zero : Nat"
  , "| suc (n : Nat) : Nat"
  , "end # comments never hurt nobody"

  , "def one : Nat where"
  , "suc zero   # and comments never will   "
  , "end"

  , "def two : Nat where"
  , "suc one"
  , "end"

  , "data Fin (n : Nat) : Type where "
  , "| iz (n : Nat) : Fin (suc n)"
  , "| is (n : Nat) (i : Fin n) : Fin (suc n)"
  , "end"

  , "def ione : Fin two where"
  , "is one (iz zero)"
  , "end"

  , "def ioneAlmost (i : Fin one) : Fin two where"
  , "is one"
  , "end"
  ]

duplicateDef = unlines
  [ "def Foo : Type where"
  , "Type"
  , "end"

  , "def Foo : Type where"
  , "Type"
  , "end"
  ]

duplicateFormer = unlines
  [ "data Foo : Type where"
  , "end"

  , "data Foo : Type where"
  , "end"
  ]

duplicateConstructor = unlines
  [ "data Foo : Type where"
  , "| dup : Foo"
  , "end"

  , "data Bar : Type where"
  , "| dup : Bar"
  , "end"
  ]

enumerationPatterns = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "def not (b : Bool) : Bool where"
  , "| true = false"
  , "| false = true"
  , "end"

  , "def nand (b1 b2 : Bool) : Bool where"
  , "| true true = false"
  , "| b1 b2 = true"
  , "end"

  , "data RGB : Type where"
  , "| red/green/blue : RGB"
  , "end"

  , "def colorBlind (r : RGB) : Bool where"
  , "| green = false"
  , "| r = true"
  , "end"
  ]

nonDependentPatterns = unlines
  [ "data Nat : Type where"
  , "| zero : Nat"
  , "| suc (n : Nat) : Nat"
  , "end"

  , "def pred (n : Nat) : Nat where"
  , "| zero = zero"
  , "| (suc n) = n"
  , "end"

  , "def add (n m : Nat) : Nat where"
  , "| zero m = m"
  , "| (suc n) m = suc (add n m)"
  , "end"

  , "def mult (n m : Nat) : Nat where"
  , "| zero m = zero"
  , "| (suc n) m = add n (mult n m)"
  , "end"

  , "def max (x y : Nat) : Nat where"
  , "| x zero = x"
  , "| zero y = y"
  , "| (suc x) (suc y) = suc (max x y)"
  , "end"
  ]

simpleComputingPatterns = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "data Nat : Type where"
  , "| zero : Nat"
  , "| suc (n : Nat) : Nat"
  , "end"

  , "def add (n m : Nat) : Nat where"
  , "| zero m = m"
  , "| (suc n) m = suc (add n m)"
  , "end"

  , "data Bits (n : Nat) : Type where"
  , "| nil : Bits zero"
  , "| cons (n : Nat) (b : Bool) (bs : Bits n) : Bits (suc n)"
  , "end"

  , "def zeroPad (n m : Nat) (bs : Bits m) : Bits (add n m) where"
  , "| zero m bs = bs"
  , "| (suc n) m bs = cons (add n m) false (zeroPad n m bs)"
  , "end"

  , "data Id (A : Type) (x y : A) : Type where"
  , "| refl (A : Type) (x : A) : Id A x x"
  , "end"

  , "def one : Nat where"
  , "suc zero"
  , "end"

  , "def two : Nat where"
  , "suc one"
  , "end"

  , "def three : Nat where"
  , "suc two"
  , "end"

  , "def testAdd : Id Nat three (add two one) where"
  , "refl Nat three"
  , "end"
  ]

simpleCapturingRHS = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "data Sing (b : Bool) : Type where"
  , "| sing : (b : Bool) : Sing b "
  , "end"

  , "def capture (x x : Bool) : Sing x where"
  , "| y true = sing true"
  , "| y false = sing false"
  , "end"
  ]

unreachableIllTypedNonDependent = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "data Nat : Type where"
  , "| zero : Nat"
  , "| suc (n : Nat) : Nat"
  , "end"

  , "def illNot (b : Bool) : Bool where"
  , "| zero = false"
  , "| b = true"
  , "end"
  ]

unreachableMultipleWildcardsNonDependent = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "def illNot (b : Bool) : Bool where"
  , "| b1 = false"
  , "| b2 = true"
  , "end"
  ]

nonLinearPatterns = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "data Bits : Type where"
  , "| nil : Bits"
  , "| cons (b : Bool) (bs : Bits) : Bits"
  , "end"

  , "def emptyBits (bs : Bits) : Bits where"
  , "| nil = nil"
  , "| (cons b b) = nil"
  , "end"
  ]


uncoveredNonDependent = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "data Nat : Type where"
  , "| zero : Nat"
  , "| suc (n : Nat) : Nat"
  , "end"

  , "def illNot (b : Bool) : Bool where"
  , "| zero = false"
  , "| false = true"
  , "end"
  ]

captureConArgs = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "data Foo (b : Bool) : Type where"
  , "| foo (b b : Bool) : Foo b"
  , "end"

  , "def captureTest : Foo true where"
  , "foo false true"
  , "end"
  ]

inferringCon = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "data Sing (A : Type) (a : A) : Type where"
  , "| sing (A : Type) (a : A) : Sing A a"
  , "end"

  , "data Foo (b : Bool) (s : Sing Bool b) : Type where"
  , "| foo (b : Bool) (s : Sing Bool b) : Foo b s"
  , "end"

  , "def captureTest : Foo true (sing Bool true) where"
  , "foo true (sing Bool true)"
  , "end"
  ]

captureDeltaWithLambda = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "def capture (b : Bool) : Bool where"
  , "(Bool : Bool) = Bool"
  , "end"
  ]

captureType = unlines
  [ "def Foo : Type where"
  , "Type"
  , "end"

  , "def foo (Foo : Foo) : Type where"
  , "(Foo : Foo) = Foo"
  , "end"
  ]

captureDataType = unlines
  [ "data Empty : Type where"
  , "end"

  , "def Empty2 : Type where"
  , "Empty"
  , "end"

  , "def capture (e : Empty) (A : Type) : Empty2 where"
  , "(e : Empty) (Empty : Type) = e"
  , "end"
  ]

exFalsoCapture = unlines
  [ "def exFalso (A : Type) (a : A) (B : Type) : B where"
  , "(A : Type) (a : A) (A : Type) = a"
  , "end"
  ]

captureDeltaWithCoveringWithoutBinding = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "def capture (Bool : Bool) : Type where"
  , "| b = Type"
  , "end"
  ]

captureDeltaWithCoveringWithBinding = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "data Sing (b : Bool) : Type where"
  , "| sing : (b : Bool) : Sing b"
  , "end"

  , "def capture (Bool : Bool) : Sing Bool where"
  , "| b = sing b"
  , "end"
  ]

simpleDependentPatterns = unlines
  [ "data Bool : Type where"
  , "| true/false : Bool"
  , "end"

  , "data Nat : Type where"
  , "| zero : Nat"
  , "| suc (n : Nat) : Nat"
  , "end"

  , "def add (n m : Nat) : Nat where"
  , "| zero m = m"
  , "| (suc n) m = suc (add n m)"
  , "end"

  , "def mult (n m : Nat) : Nat where"
  , "| zero m = zero"
  , "| (suc n) m = add n (mult n m)"
  , "end"

  , "data Bits (n : Nat) : Type where"
  , "| nil : Bits zero"
  , "| cons (n : Nat) (b : Bool) (bs : Bits n) : Bits (suc n)"
  , "end"

  , "def append (n m : Nat) (xs : Bits n) (ys : Bits m) : Bits (add n m) where"
  , "| * m nil ys = ys"
  , "| * m (cons n x xs) ys = cons (add n m) x (append n m xs ys)"
  , "end"

  , "def copyBits (n : Nat) (bs : Bits n) : Bits n where"
  , "| * nil = nil"
  , "| * (cons n b bs) = cons n b bs"
  , "end"
  ]

dependentVectorPatterns = unlines
  [ "data Nat : Type where"
  , "| zero : Nat"
  , "| suc (n : Nat) : Nat"
  , "end"

  , "def add (n m : Nat) : Nat where"
  , "| zero m = m"
  , "| (suc n) m = suc (add n m)"
  , "end"

  , "def mult (n m : Nat) : Nat where"
  , "| zero m = zero"
  , "| (suc n) m = add m (mult n m)"
  , "end"

  , "data Vec (A : Type) (n : Nat) : Type where"
  , "| nil (A : Type) : Vec A zero"
  , "| cons (A : Type) (n : Nat) (x : A) (xs : Vec A n) : Vec A (suc n)"
  , "end"

  , "def append (A : Type) (n m : Nat) (xs : Vec A n) (ys : Vec A m) : Vec A (add n m) where"
  , "| A * m (nil *) ys = ys"
  , "| A * m (cons * n x xs) ys = cons A (add n m) x (append A n m xs ys)"
  , "end"

  , "def concat (A : Type) (n m : Nat) (xss : Vec (Vec A m) n) : Vec A (mult n m) where"
  , "| A * m (nil *) = nil A"
  , "| A * m (cons * n xs xss) = append A m (mult n m) xs (concat A n m xss)"
  , "end"
  ]

whnfTests :: Test
whnfTests = "Whnf tests" ~:
  [ testWhnf "Type" "Type"
  , testWhnf "((A : Type) (a : A) = a) Type Type" "Type"
  , testWhnf ("((A : Type) (a : A) = a) Type " ++ _Identity) _Identity
  , testWhnf (identity ++ " Type " ++ _PiWh) _PiWh
  , testWhnfFails (identity ++ " Type " ++ _PiWh) "(B : Type) : Type"
  ]

convTests :: Test
convTests = "Conv tests" ~:
  [ testConv "Type" "Type"
  , testConv (identity ++ "Type Type") "Type"
  , testConv "(A : Type) (a : A) = a" "(B : Type) (b : B) = b"
  , testConv (identity ++ " Type " ++ _PiWh) "(B : Type) : Type"
  ]

checkTests :: Test
checkTests = "Check tests" ~:
  [ testCheck "Type" "Type"
  , testCheckFails "(x : A) : B x" "Type"
  , testCheck "(x : Type) : Type" "Type"
  , testCheck _Identity "Type"
  , testCheck identity _Identity
  , testCheck "(B : Type) (b : B) = b" _Identity
  , testCheckFails identity "Type"
  , testCheck ("(A : Type) (a : A) = (" ++ identity ++ " A) (" ++ identity ++ " A a)") _Identity
  , testChecks idProg
  , testChecks dataProg
  , testChecksFails duplicateDef
  , testChecksFails duplicateFormer
  , testChecksFails duplicateConstructor
  , testChecks enumerationPatterns
  , testChecks nonDependentPatterns
  , testChecks simpleComputingPatterns
  , testChecks simpleCapturingRHS
  , testChecksFails unreachableIllTypedNonDependent
  , testChecksFails unreachableMultipleWildcardsNonDependent
  , testChecksFails uncoveredNonDependent
  , testChecksFails nonLinearPatterns
  , testChecks captureConArgs
  , testChecks inferringCon
  , testChecks captureDeltaWithLambda
  , testChecks captureType
  , testChecks captureDataType
  , testChecksFails exFalsoCapture
  , testChecks captureDeltaWithCoveringWithoutBinding
  , testChecks captureDeltaWithCoveringWithBinding
  , testChecks simpleDependentPatterns
  , testChecks dependentVectorPatterns
  ]

parseTests :: Test
parseTests = "Parse tests" ~:
  [ testParse "Type" (Just Type)
  , testParse "A" (Just (Var (s2n "A")))
  , testParse "F x y z" Nothing
  , testParseFails "(x : where) (y : B) : Type"
  , testParseFails "(Type : A) (y : B) : Type"
  , testParse "(x : A) (y : B) : Type" Nothing
  , testParse "(x : A) (y : B x) : C x y" Nothing
  , testParse "(x : A) (y : B) = c" Nothing
  , testParse "(x : A) (y : B x) : C (((z : A) = z) x) (g x y)" Nothing
  , testParses idProg
  , testParses enumerationPatterns
  , testParses nonDependentPatterns
  ]

----------------------------------------------------------------------

unitTests :: Test
unitTests = TestList [parseTests, checkTests, convTests, whnfTests]

runTests :: IO Counts
runTests = runTestTT unitTests

main = runTests >> return ()

----------------------------------------------------------------------

asProg :: String -> [Stmt]
asProg s = case parseP s of
  Right a -> a
  Left e -> error (show e)

asExp :: String -> Exp
asExp s = case parseE s of
  Right a -> a
  Left e -> error (show e)

----------------------------------------------------------------------

testWhnf :: String -> String -> Test
testWhnf a b = TestCase $ case runWhnf (asExp a) of
  Left error -> assertFailure ("Whnf error:\n" ++ error)
  Right a' -> let
    error = "Whnf error:\n" ++ show a' ++ " != " ++ show (asExp b)
    in assertBool error (alpha a' (asExp b))

testWhnfFails :: String -> String -> Test
testWhnfFails a b = TestCase $ case runWhnf (asExp a) of
  Left error -> assertFailure ("Unexpected whnf error:\n" ++ error)
  Right a' -> let
    error = "Whnf reduced too much error:\n" ++ show a'
    in assertBool error (not (alpha a' (asExp b)))

----------------------------------------------------------------------

testConv :: String -> String -> Test
testConv a b = TestCase $ case runConv (asExp a) (asExp b) of
  Left error -> assertFailure ("Conv error:\n" ++ error)
  Right _ -> return ()

----------------------------------------------------------------------

testChecksDelta :: String -> Test
testChecksDelta ds = TestCase $ case runCheckProgDelta (asProg ds) of
  Left error -> assertFailure ("Check error:\n" ++ error)
  Right () -> return ()

----------------------------------------------------------------------

testChecks :: String -> Test
testChecks ds = TestCase $ case runCheckProgDelta (asProg ds) of
  Left error -> assertFailure ("Check error:\n" ++ error)
  Right () -> return ()

testCheck :: String -> String -> Test
testCheck a _A = TestCase $ case runCheck (asExp a) (asExp _A) of
  Left error -> assertFailure ("Check error:\n" ++ error)
  Right () -> return ()

testChecksFails :: String -> Test
testChecksFails ds = TestCase $ case runCheckProg (asProg ds) of
  Right () -> assertFailure ("Expected check error in program:\n" ++ ds)
  Left error -> return ()

testCheckFails :: String -> String -> Test
testCheckFails a _A = TestCase $ case runCheck (asExp a) (asExp _A) of
  Right () -> assertFailure ("Expected check error:\n" ++ (a ++ " : " ++ _A))
  Left error -> return ()

----------------------------------------------------------------------

testParses :: String -> Test
testParses s = TestCase $ case parseP s of
  Left error -> assertFailure ("Parse error:\n" ++ show error)
  Right xs -> return ()

testParse :: String -> Maybe Exp -> Test
testParse s ma = TestCase $ case parseE s of
  Left error -> assertFailure ("Parse error:\n" ++ show error)
  Right a -> maybe (return ()) (@=? a) ma

testParseFails :: String -> Test
testParseFails s = TestCase $ case parseE s of
  Left error -> return ()
  Right a -> assertFailure ("Expected parse error:\n" ++ show a)

----------------------------------------------------------------------
