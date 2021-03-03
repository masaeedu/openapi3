-- |
-- Module:      Data.OpenApi.Schema
-- Maintainer:  Nickolay Kudasov <nickolay@getshoptv.com>
-- Stability:   experimental
--
-- Types and functions for working with Swagger schema.
module Data.OpenApi.Schema (
  -- * Encoding
  ToSchema(..),
  declareSchema,
  declareSchemaRef,
  toSchema,
  toSchemaRef,
  schemaName,
  toInlinedSchema,
  ToSchema1(..),
  BySchema1(..),

  -- * Generic schema encoding
  genericDeclareNamedSchema,
  genericDeclareSchema,
  genericDeclareNamedSchemaNewtype,
  genericNameSchema,

  -- ** 'Bounded' 'Integral'
  genericToNamedSchemaBoundedIntegral,
  toSchemaBoundedIntegral,

  -- ** 'Bounded' 'Enum' key mappings
  declareSchemaBoundedEnumKeyMapping,
  toSchemaBoundedEnumKeyMapping,

  -- ** Reusing 'ToParamSchema'
  paramSchemaToNamedSchema,
  paramSchemaToSchema,

  -- * Sketching @'Schema'@s using @'ToJSON'@
  sketchSchema,
  sketchStrictSchema,

  -- * Inlining @'Schema'@s
  inlineNonRecursiveSchemas,
  inlineAllSchemas,
  inlineSchemas,
  inlineSchemasWhen,

  -- * Generic encoding configuration
  SchemaOptions(..),
  defaultSchemaOptions,
  fromAesonOptions,
) where

import Data.OpenApi.Internal.Schema
import Data.OpenApi.SchemaOptions