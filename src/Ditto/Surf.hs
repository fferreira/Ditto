module Ditto.Surf where
import Ditto.Syntax
import Ditto.Monad
import Ditto.Sub
import Ditto.Whnf
import Data.Maybe

----------------------------------------------------------------------

surfs :: Env -> TCM Prog
surfs env = map Left <$> (surfs' env [])

surfs' :: Env -> [PName] -> TCM [Stmt]
surfs' [] xs = return []
surfs' (Def x a _A:env) xs = if isDeltaName x xs
  then surfs' env xs
  else (:) <$> (SDef x <$> defBod <*> surfExp _A) <*> surfs' env xs
  where defBod = maybe (return hole) surfExp a
surfs' (DForm _X cs _Is:env) (((_X:conNames cs)++) -> xs) = do
  cs <- mapM (\(y, _As, is) -> (y,) <$> surfExp (conType _As _X is)) cs
  (:) <$> (SData _X <$> surfExp (formType _Is) <*> return cs) <*> surfs' env xs
surfs' (DRed x cs _As _B:env) ((x:) -> xs) = do
  cs <- mapM (\(_, ps, rhs) -> (,) <$> surfPats ps <*> surfRHS rhs) cs
  (:) <$> (SDefn x <$> surfExp (pis _As _B) <*> return cs) <*> surfs' env xs
surfs' (DMeta x ma _As _B:env) xs = surfs' env xs
surfs' (DGuard x a _A:env) xs = surfs' env xs

isDeltaName :: Name -> [PName] -> Bool
isDeltaName x xs = maybe False (flip elem xs) (name2pname x)

----------------------------------------------------------------------

metaExpand = surfExp

surfExp :: Exp -> TCM Exp
surfExp (Pi i _A _B) = Pi i <$> surfExp _A <*> surfExpExtBind i _A _B
surfExp (Form x as) = Form x <$> surfExps as
surfExp (Con x as) = Con x <$> surfExps as
surfExp (viewSpine -> (Meta x as1, as2)) = lookupMeta x >>= \case
  Just a -> surfExp =<< whnf (apps a (as1 ++ as2))
  Nothing -> apps <$> (Meta x <$> surfExps as1) <*> surfExps as2
surfExp (viewSpine -> (Guard x, as)) = lookupGuard x >>= \case
  Just a -> surfExp =<< whnf (apps a as)
  Nothing -> apps (Guard x) <$> surfExps as
surfExp (viewSpine -> (Red x as1, as2)) =
  apps <$> (Red x <$> surfExps as1) <*> surfExps as2
surfExp (viewSpine -> (Var x, as)) =
  apps (Var x) <$> surfExps as
surfExp (viewSpine -> (Lam i _A b, as)) =
  apps <$> (Lam i <$> surfExp _A <*> surfExpExtBind i _A b) <*> surfExps as
surfExp a = return a

surfExps :: Args -> TCM Args
surfExps = mapM (\(i, a) -> (i,) <$> surfExp a)

surfExpExtBind :: Icit -> Exp -> Bind -> TCM Bind
surfExpExtBind i _A bnd_b = do
  (x, b) <- unbind bnd_b
  Bind x <$> extCtx i x _A (surfExp b)

----------------------------------------------------------------------

surfHoles :: Holes -> TCM Holes
surfHoles = mapM surfHole

surfHole :: Hole -> TCM Hole
surfHole (x, _As, _B) = (x,,) <$> surfTel _As <*> surfExp _B

surfTel :: Tel -> TCM Tel
surfTel = mapM (\(i, x, _A) -> (i,x,) <$> surfExp _A)

----------------------------------------------------------------------

surfClauses :: [CheckedClause] -> TCM [CheckedClause]
surfClauses = mapM surfClause

surfClause :: CheckedClause -> TCM CheckedClause
surfClause (_As, ps, rhs) = (,,)
  <$> surfTel _As <*> surfPats ps <*> surfRHS rhs

surfPats :: Pats -> TCM Pats
surfPats = mapM (\(i, a) -> (i,) <$> surfPat a)

surfPat :: Pat -> TCM Pat
surfPat (PVar x) = PVar <$> return x
surfPat (PInacc ma) = PInacc <$> traverse surfExp ma
surfPat (PCon x ps) = PCon x <$> surfPats ps

surfRHS :: RHS -> TCM RHS
surfRHS (MapsTo a) = MapsTo <$> surfExp a
surfRHS (Caseless x) = Caseless <$> return x
surfRHS (Split x) = Split <$> return x

----------------------------------------------------------------------