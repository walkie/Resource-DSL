module DSL.Environment where

import Data.Composition ((.:))
import Data.List (union)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)

import DSL.Types


--
-- * Generic environments
--

-- ** Construction

-- | Empty enivornment.
envEmpty :: Env k v
envEmpty = Env Map.empty

-- | Singleton environment.
envSingle :: k -> v -> Env k v
envSingle = Env .: Map.singleton

-- | Construct an environment from an association list.
envFromList :: Ord k => [(k,v)] -> Env k v
envFromList = Env . Map.fromList

-- | Construct an environment from an association list, merging duplicates.
envFromListAcc :: (Ord k, MergeDup m) => [(k,m)] -> Env k m
envFromListAcc []        = envEmpty
envFromListAcc ((k,m):l) = envUnionWith mergeDup (envSingle k m) (envFromListAcc l)

-- | Type class for merging duplicate values when constructing an environment
--   from an association list.
class MergeDup v where
  mergeDup :: v -> v -> v

instance MergeDup Int where
  mergeDup = (+)

instance MergeDup [a] where
  mergeDup = (++)

-- Throw an error if we attempt to merge two primitive values.
instance MergeDup Value where
  mergeDup _ _ = error "mergeDup (Value): attempted to merge duplicate entries"

-- | Compose two models by sequencing the statements in their bodies.
--   Merges parameters by name.
composeModels :: Model -> Model -> Model
composeModels (Model ps1 b1) (Model ps2 b2) =
    Model (union ps1 ps2) (b1 ++ b2)

instance MergeDup Model where
  mergeDup = composeModels


-- ** Operations

-- | Convert an environment into an association list.
envToList :: Env k v -> [(k,v)]
envToList (Env m) = Map.toList m

-- | Apply a function to the map that implements this environment.
envOnMap :: (Map a b -> Map c d) -> Env a b -> Env c d
envOnMap f (Env m) = Env (f m)

-- | Check whether an environment contains a particular name.
envHas :: Ord k => k -> Env k v -> Bool
envHas k = Map.member k . envAsMap

-- | Extend an environment with a new name binding.
envExtend :: Ord k => k -> v -> Env k v -> Env k v
envExtend = envOnMap .: Map.insert

-- | Extend an environment with a list of new name binding.
envExtends :: Ord k => [(k,v)] -> Env k v -> Env k v
envExtends = envUnion . envFromList

-- | Delete a binding in an environment.
envDelete :: Ord k => k -> Env k v -> Env k v
envDelete = envOnMap . Map.delete

-- | Left-biased union of two environments.
envUnion :: Ord k => Env k v -> Env k v -> Env k v
envUnion (Env l) (Env r) = Env (Map.union l r)

-- | Left-biased union of two environments.
envUnionWith :: Ord k => (v -> v -> v) -> Env k v -> Env k v -> Env k v
envUnionWith f (Env l) (Env r) = Env (Map.unionWith f l r)

-- | Lookup a binding in an environment.
envLookup :: Ord k => k -> Env k v -> Maybe v
envLookup k (Env m) = Map.lookup k m

-- | Lookup a binding in an environment, failing with a runtim error if it
--   doesn't exist.
envLookupOrFail :: (Show k, Ord k) => String -> k -> Env k v -> v
envLookupOrFail s k = fromMaybe err . envLookup k
  where err = error ("Lookup failed in " ++ s ++ ": " ++ show k)

-- | Apply a result-less monadic action to all key-value pairs.
envMapM_ :: Monad m => (k -> v -> m ()) -> Env k v -> m ()
envMapM_ f = mapM_ (uncurry f) . Map.toAscList . envAsMap
