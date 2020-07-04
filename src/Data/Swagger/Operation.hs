{-# LANGUAGE RankNTypes #-}
-- |
-- Module:      Data.Swagger.Operation
-- Maintainer:  Nickolay Kudasov <nickolay@getshoptv.com>
-- Stability:   experimental
--
-- Helper traversals and functions for Swagger operations manipulations.
-- These might be useful when you already have Swagger specification
-- generated by something else.
module Data.Swagger.Operation (
  -- * Operation traversals
  allOperations,
  operationsOf,

  -- * Manipulation
  -- ** Tags
  applyTags,
  applyTagsFor,

  -- ** Responses
  setResponse,
  setResponseWith,
  setResponseFor,
  setResponseForWith,

  -- ** Paths
  prependPath,

  -- * Miscellaneous
  declareResponse,
) where

import Prelude ()
import Prelude.Compat

import Control.Lens
import Data.Data.Lens
import Data.List.Compat
import Data.Maybe (mapMaybe)
import Data.Proxy
import qualified Data.Set as Set
import Data.Text (Text)

import Data.Swagger.Declare
import Data.Swagger.Internal
import Data.Swagger.Lens
import Data.Swagger.Schema

import qualified Data.HashMap.Strict.InsOrd as InsOrdHashMap
import qualified Data.HashSet.InsOrd as InsOrdHS

-- $setup
-- >>> import Data.Aeson
-- >>> import Data.Proxy
-- >>> import Data.Time
-- >>> import qualified Data.ByteString.Lazy.Char8 as BSL

-- | Prepend path piece to all operations of the spec.
-- Leading and trailing slashes are trimmed/added automatically.
--
-- >>> let api = (mempty :: Swagger) & paths .~ [("/info", mempty)]
-- >>> BSL.putStrLn $ encode $ prependPath "user/{user_id}" api ^. paths
-- {"/user/{user_id}/info":{}}
prependPath :: FilePath -> Swagger -> Swagger
prependPath path = paths %~ InsOrdHashMap.mapKeys (path </>)
  where
    x </> y = case trim y of
      "" -> "/" <> trim x
      y' -> "/" <> trim x <> "/" <> y'

    trim = dropWhile (== '/') . dropWhileEnd (== '/')

-- | All operations of a Swagger spec.
allOperations :: Traversal' Swagger Operation
allOperations = paths.traverse.template

-- | @'operationsOf' sub@ will traverse only those operations
-- that are present in @sub@. Note that @'Operation'@ is determined
-- by both path and method.
--
-- >>> let ok = (mempty :: Operation) & at 200 ?~ "OK"
-- >>> let api = (mempty :: Swagger) & paths .~ [("/user", mempty & get ?~ ok & post ?~ ok)]
-- >>> let sub = (mempty :: Swagger) & paths .~ [("/user", mempty & get ?~ mempty)]
-- >>> BSL.putStrLn $ encode api
-- {"openapi":"3.0.0","info":{"version":"","title":""},"paths":{"/user":{"get":{"responses":{"200":{"description":"OK"}}},"post":{"responses":{"200":{"description":"OK"}}}}},"components":{}}
-- >>> BSL.putStrLn $ encode $ api & operationsOf sub . at 404 ?~ "Not found"
-- {"openapi":"3.0.0","info":{"version":"","title":""},"paths":{"/user":{"get":{"responses":{"404":{"description":"Not found"},"200":{"description":"OK"}}},"post":{"responses":{"200":{"description":"OK"}}}}},"components":{}}
operationsOf :: Swagger -> Traversal' Swagger Operation
operationsOf sub = paths.itraversed.withIndex.subops
  where
    -- | Traverse operations that correspond to paths and methods of the sub API.
    subops :: Traversal' (FilePath, PathItem) Operation
    subops f (path, item) = case InsOrdHashMap.lookup path (sub ^. paths) of
      Just subitem -> (,) path <$> methodsOf subitem f item
      Nothing      -> pure (path, item)

    -- | Traverse operations that exist in a given @'PathItem'@
    -- This is used to traverse only the operations that exist in sub API.
    methodsOf :: PathItem -> Traversal' PathItem Operation
    methodsOf pathItem = partsOf template . itraversed . indices (`elem` ns) . _Just
      where
        ops = pathItem ^.. template :: [Maybe Operation]
        ns = mapMaybe (fmap fst . sequenceA) $ zip [0..] ops

-- | Apply tags to all operations and update the global list of tags.
--
-- @
-- 'applyTags' = 'applyTagsFor' 'allOperations'
-- @
applyTags :: [Tag] -> Swagger -> Swagger
applyTags = applyTagsFor allOperations

-- | Apply tags to a part of Swagger spec and update the global
-- list of tags.
applyTagsFor :: Traversal' Swagger Operation -> [Tag] -> Swagger -> Swagger
applyTagsFor ops ts swag = swag
  & ops . tags %~ (<> InsOrdHS.fromList (map _tagName ts))
  & tags %~ (<> InsOrdHS.fromList ts)

-- | Construct a response with @'Schema'@ while declaring all
-- necessary schema definitions.
--
-- FIXME doc
--
-- >>> BSL.putStrLn $ encode $ runDeclare (declareResponse "application/json" (Proxy :: Proxy Day)) mempty
-- [{"Day":{"example":"2016-07-22","format":"date","type":"string"}},{"description":"","content":{"application/json":{"schema":{"$ref":"#/components/schemas/Day"}}}}]
declareResponse :: ToSchema a => Text -> Proxy a -> Declare (Definitions Schema) Response
declareResponse cType proxy = do
  s <- declareSchemaRef proxy
  return (mempty & content.at cType ?~ (mempty & schema ?~ s))

-- | Set response for all operations.
-- This will also update global schema definitions.
--
-- If the response already exists it will be overwritten.
--
-- @
-- 'setResponse' = 'setResponseFor' 'allOperations'
-- @
--
-- Example:
--
-- >>> let api = (mempty :: Swagger) & paths .~ [("/user", mempty & get ?~ mempty)]
-- >>> let res = declareResponse "application/json" (Proxy :: Proxy Day)
-- >>> BSL.putStrLn $ encode $ api & setResponse 200 res
-- {"openapi":"3.0.0","info":{"version":"","title":""},"paths":{"/user":{"get":{"responses":{"200":{"content":{"application/json":{"schema":{"$ref":"#/components/schemas/Day"}}},"description":""}}}}},"components":{"schemas":{"Day":{"example":"2016-07-22","format":"date","type":"string"}}}}
--
-- See also @'setResponseWith'@.
setResponse :: HttpStatusCode -> Declare (Definitions Schema) Response -> Swagger -> Swagger
setResponse = setResponseFor allOperations

-- | Set or update response for all operations.
-- This will also update global schema definitions.
--
-- If the response already exists, but it can't be dereferenced (invalid @\$ref@),
-- then just the new response is used.
--
-- @
-- 'setResponseWith' = 'setResponseForWith' 'allOperations'
-- @
--
-- See also @'setResponse'@.
setResponseWith :: (Response -> Response -> Response) -> HttpStatusCode -> Declare (Definitions Schema) Response -> Swagger -> Swagger
setResponseWith = setResponseForWith allOperations

-- | Set response for specified operations.
-- This will also update global schema definitions.
--
-- If the response already exists it will be overwritten.
--
-- See also @'setResponseForWith'@.
setResponseFor :: Traversal' Swagger Operation -> HttpStatusCode -> Declare (Definitions Schema) Response -> Swagger -> Swagger
setResponseFor ops code dres swag = swag
  & components.schemas %~ (<> defs)
  & ops . at code ?~ Inline res
  where
    (defs, res) = runDeclare dres mempty

-- | Set or update response for specified operations.
-- This will also update global schema definitions.
--
-- If the response already exists, but it can't be dereferenced (invalid @\$ref@),
-- then just the new response is used.
--
-- See also @'setResponseFor'@.
setResponseForWith :: Traversal' Swagger Operation -> (Response -> Response -> Response) -> HttpStatusCode -> Declare (Definitions Schema) Response -> Swagger -> Swagger
setResponseForWith ops f code dres swag = swag
  & components.schemas %~ (<> defs)
  & ops . at code %~ Just . Inline . combine
  where
    (defs, new) = runDeclare dres mempty

    combine (Just (Ref (Reference n))) = case swag ^. components.responses.at n of
      Just old -> f old new
      Nothing  -> new -- response name can't be dereferenced, replacing with new response
    combine (Just (Inline old)) = f old new
    combine Nothing = new
