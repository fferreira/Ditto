module Ditto.Check where
import Ditto.Syntax
import Ditto.Monad
import Ditto.Env
import Ditto.Sub
import Ditto.Whnf
import Ditto.Conv
import Ditto.Solve
import Ditto.Match
import Ditto.Cover
import Ditto.Surf
import Ditto.Throw
import Ditto.During
import Ditto.Pretty
import Data.Maybe
import Data.List
import Control.Monad.State

----------------------------------------------------------------------

runPipeline :: Verbosity -> TCM a -> (a -> b) -> Either String b
runPipeline v p f = case runTCM v p of
  Left (xs, env, acts, ctx, err) ->
    Left . render . ppCtxErr v xs env acts ctx $ err
  Right a -> Right (f a)

runPipelineV = runPipeline Verbose

runCheckProg :: Verbosity -> Prog -> Either String String
runCheckProg v ds = runPipeline v (checkProg ds) post
  where
  post (xs, env, holes) = render . ppCtxHoles v xs env $ holes

----------------------------------------------------------------------

checkProg :: Prog -> TCM ([Name], Prog, Holes)
checkProg ds = do
  mapM_ checkStmt ds
  env <- getEnv
  prog <- surfs env
  holes <- surfHoles =<< lookupHoles
  return (defNames env, prog, holes)

checkStmt :: MStmt -> TCM ()
checkStmt (Left d) = do
  checkSig (toSig d)
  checkBod (toBod d)
checkStmt (Right ds) = do
  mapM_ (checkSig . toSig) ds
  mapM_ (checkBod . toBod) ds

checkSig :: Sig -> TCM ()
checkSig (GDef x _A) = duringDef x $ do
  _A <- checkSolved _A Type
  addDef x Nothing _A
checkSig (GData x _A) = duringData x $ do
  _A <- checkSolved _A Type
  (tel, end) <- splitTel _A
  case end of
    Type -> do
      addForm x tel
    otherwise -> throwGenErr "Datatype former does not end in Type"
checkSig (GDefn x _A) = duringDefn x $ do
  _A <- checkSolved _A Type
  (_As, _B) <- splitTel _A
  addRedType x _As _B

checkBod :: Bod -> TCM ()
checkBod (BDef x a) = duringDef x $ do
  _A <- fromJust <$> lookupType x
  a  <- checkSolved a _A
  updateDef x a
checkBod (BData x cs) = duringData x $ do
  cs <- mapM (\ (x, _A') -> (x,) <$> duringCon x (checkSolved _A' Type)) cs
  mapM_ (\c -> addCon =<< buildCon x c) cs
checkBod (BDefn x cs) = duringDefn x $ do
  cs <- atomizeClauses cs
  checkLinearClauses x cs
  (_As, _B) <- fromJust <$> lookupRedType x
  cs' <- cover x cs _As
  let unreached = unreachableClauses cs cs'
  unless (null unreached) $
    throwReachErr x unreached
  addRedClauses x =<< mapM (\(_Delta, lhs, rhs) -> (_Delta, lhs,) <$> checkRHS _Delta lhs rhs _As _B) cs'

----------------------------------------------------------------------

checkRHS :: Tel -> Pats -> RHS -> Tel -> Exp -> TCM RHS
checkRHS _Delta lhs (MapsTo a) _As _B
  = MapsTo <$> (checkExtsSolved _Delta a =<< subClauseType _B _As lhs)
checkRHS _Delta lhs (Caseless x) _ _ = split _Delta x >>= \case
  [] -> return (Caseless x)
  otherwise -> throwCaselessErr x
checkRHS _Delta lhs (Split x) _ _ = do
  cs <- splitClause x _Delta lhs
  throwSplitErr cs

----------------------------------------------------------------------

checkLinearClauses :: PName -> [Clause] -> TCM ()
checkLinearClauses x = mapM_ (checkLinearClause x)

checkLinearClause :: PName -> Clause -> TCM ()
checkLinearClause x (ps, rhs) =
  unless (null xs) $ throwGenErr $ unlines
    ["Nonlinear occurrence of variables in patterns."
    , "Variables: " ++ show xs
    , "Function: " ++ show x
    , "Patterns: " ++ show ps
    ]
  where xs = nonLinearVars ps

nonLinearVars :: Pats -> [Name]
nonLinearVars ps = xs \\ nub xs
  where xs = patternsVars ps

patternsVars :: Pats -> [Name]
patternsVars = concat . map (patternVars . snd)

patternVars :: Pat -> [Name]
patternVars (PVar x) = [x]
patternVars (PInacc _) = []
patternVars (PCon _ ps) = patternsVars ps

----------------------------------------------------------------------

atomizeClauses :: [Clause] -> TCM [Clause]
atomizeClauses = mapM (\(ps, rhs) -> (,rhs) <$> atomizePatterns ps)

atomizePatterns :: Pats -> TCM Pats
atomizePatterns = mapM (\(i, p) -> (i,) <$> atomizePattern p)

atomizePattern :: Pat -> TCM Pat
atomizePattern (PVar x) = case name2pname x of
  Just x' -> lookupPSigma x' >>= \case
    Just (DForm _ _ _) -> return $ PCon x' []
    otherwise -> return $ PVar x
  Nothing -> return $ PVar x
atomizePattern (PCon x ps) = PCon x <$> atomizePatterns ps
atomizePattern x@(PInacc _) = return x

----------------------------------------------------------------------

checkSolved :: Exp -> Exp -> TCM Exp
checkSolved a _A = do
  a <- check a _A
  ensureSolved
  return a

checkExtsSolved :: Tel -> Exp -> Exp -> TCM Exp
checkExtsSolved _As b _B = do
  b <- checkExts _As b _B
  ensureSolved
  return b

ensureSolved :: TCM ()
ensureSolved = do
  ps <- unsolvedProbs
  hs <- lookupUndefMetas
  unless (null ps && null hs) (throwUnsolvedErr ps hs)

----------------------------------------------------------------------

checkExt :: Icit -> Name -> Exp -> Exp -> Exp -> TCM Exp
checkExt i x _A = checkExts [(i, x, _A)]

checkExts :: Tel -> Exp -> Exp -> TCM Exp
checkExts _As b _B = extCtxs _As (check b _B)

inferExtBind :: Icit -> Exp -> Bind -> TCM (Bind, Bind)
inferExtBind i _A bnd_b = do
  (x, b) <- unbind bnd_b
  (b, _B) <- extCtx i x _A (infer b)
  return (Bind x b, Bind x _B)

----------------------------------------------------------------------

check :: Exp -> Exp -> TCM Exp
check a _A = duringCheck a _A $ do
  (a , _A') <- infer a
  conv _A' _A >>= \case
    Nothing -> do
      solveProbs
      return a
    Just p -> do
      a <- genGuard a _A p
      solveProbs
      return a

infer :: Exp -> TCM (Exp, Exp)
infer b@(viewSpine -> (f, as)) = duringInfer b $ do
  (f, _AB) <- inferAtom f
  (as, _B) <- checkArgs as =<< whnf _AB
  return (apps f as, _B)

checkArgs :: Args -> Exp -> TCM (Args, Exp)
checkArgs as@((Expl, _):_) _AB@(Pi Impl _ _) =
  checkArgs ((Impl, Infer MInfer):as) _AB
checkArgs [] _AB@(Pi Impl _ _) =
  checkArgs [(Impl, Infer MInfer)] _AB
checkArgs ((i1, a):as) (Pi i2 _A bnd_B) | i1 == i2 = do
  a <- check a _A
  (x, _B) <- unbind bnd_B
  (as, _B) <- checkArgs as =<< whnf =<< sub1 (x, a) _B
  return ((i1, a):as, _B)
checkArgs as@((i, _):_) _M@(Meta _X _) = do
  (_As, _) <- fromJust <$> lookupMetaType _X
  _AB <- genMetaPi _As i
  conv _M _AB
  checkArgs as _AB
checkArgs ((i1, a):as) _B =
  throwGenErr "Function does not have correct Pi type"
checkArgs [] _B = return ([], _B)

inferAtom :: Exp -> TCM (Exp, Exp)
inferAtom (Var x) = lookupType x >>= \case
  Just _A -> return (Var x, _A)
  Nothing -> throwScopeErr x
inferAtom Type = return (Type, Type)
inferAtom (Infer m) = genMeta m
inferAtom (Pi i _A bnd_B) = do
  _A <- check _A Type
  (x, _B) <- unbind bnd_B
  _B <- checkExt i x _A _B Type
  return (Pi i _A (Bind x _B), Type)
inferAtom (Lam i _A b) = do
  _A <- check _A Type
  (b , _B) <- inferExtBind i _A b
  return (Lam i _A b, Pi i _A _B)
inferAtom x = throwAtomErr x

----------------------------------------------------------------------
