{-# LANGUAGE CPP                        #-}
{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE DeriveFoldable             #-}
{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE DeriveTraversable          #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

#if __GLASGOW_HASKELL__ >= 702
{-# LANGUAGE DeriveGeneric              #-}
#else
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}
#endif

{-|
Module:      TransformersCompat
Copyright:   (C) 2014-2015 Ryan Scott
License:     BSD-style (see the file LICENSE)
Maintainer:  Ryan Scott
Stability:   Provisional
Portability: GHC

Defines the 'Show1' and 'Show2' classes for @String@s. This module will be removed
once the next version of @transformers@/@transformers-compat@ is released.
-}
module TransformersCompat (
    -- * Liftings of Prelude classes
    -- ** For unary constructors
    Show1(..), showsPrec1,
    -- ** For binary constructors
    Show2(..), showsPrec2,
    -- * Helper functions
    showsUnaryWith,
    showsBinaryWith,
    -- * Conversion between @Text-@ and @String@ @Show1@/@Show2@
    FromStringShow1(..), FromTextShow1(..),
    FromStringShow2(..), FromTextShow2(..)
    ) where

#include "inline.h"

import           Control.Applicative (Const(..))

import           Data.Bifunctor (Bifunctor(..))
#if __GLASGOW_HASKELL__ >= 708
import           Data.Data (Data, Typeable)
#endif
import           Data.Functor.Identity (Identity(..))

#if __GLASGOW_HASKELL__ >= 702
import           GHC.Generics (Generic)
# if __GLASGOW_HASKELL__ >= 706
import           GHC.Generics (Generic1)
# endif
#else
import qualified Generics.Deriving.TH as Generics
#endif

import           Prelude ()
import           Prelude.Compat

import           Text.Read (Read(..), readListPrecDefault)

import           TextShow (TextShow(showbPrec), TextShow1(..), TextShow2(..),
                           FromStringShow(..), FromTextShow(..),
                           showsToShowb, showbToShows, showbPrec1, showbPrec2)

-- | Lifting of the 'Show' class to unary type constructors.
class Show1 f where
    -- | Lift a 'showsPrec' function through the type constructor.
    showsPrecWith :: (Int -> a -> ShowS) -> Int -> f a -> ShowS

-- | Lift the standard 'showsPrec' function through the type constructor.
showsPrec1 :: (Show1 f, Show a) => Int -> f a -> ShowS
showsPrec1 = showsPrecWith showsPrec

-- | The 'TextShow1' instance for 'FromStringShow1' is based on its @String@
-- 'Show1' instance. That is,
--
-- @
-- showbPrecWith sp p ('FromStringShow1' x) =
--     'showsToShowb' ('showsPrecWith' ('showbToShows' sp)) p x
-- @
--
-- /Since: ?.?/
newtype FromStringShow1 f a = FromStringShow1 { fromStringShow1 :: f a }
  deriving ( Eq
           , Functor
           , Foldable
#if __GLASGOW_HASKELL__ >= 702
           , Generic
# if __GLASGOW_HASKELL__ >= 706
           , Generic1
# endif
#endif
           , Ord
           , Show1
           , Traversable
#if __GLASGOW_HASKELL__ >= 708
           , Data
           , Typeable
#endif
           )

instance Read (f a) => Read (FromStringShow1 f a) where
    readPrec = FromStringShow1 <$> readPrec
    INLINE_INST_FUN(readPrec)

    readListPrec = readListPrecDefault
    INLINE_INST_FUN(readListPrec)

instance (Show1 f, Show a) => TextShow (FromStringShow1 f a) where
    showbPrec = showbPrecWith (showsToShowb showsPrec)
    INLINE_INST_FUN(showbPrec)

instance Show1 f => TextShow1 (FromStringShow1 f) where
    showbPrecWith sp p =
        showsToShowb (showsPrecWith $ showbToShows sp) p . fromStringShow1
    INLINE_INST_FUN(showbPrecWith)

instance (Show1 f, Show a) => Show (FromStringShow1 f a) where
    showsPrec = showsPrec1
    INLINE_INST_FUN(showsPrec)

-- | Lifting of the 'Show' class to binary type constructors.
class Show2 f where
    -- | Lift 'showsPrec' functions through the type constructor.
    showsPrecWith2 :: (Int -> a -> ShowS) -> (Int -> b -> ShowS) ->
        Int -> f a b -> ShowS

-- | Lift the standard 'showsPrec' function through the type constructor.
showsPrec2 :: (Show2 f, Show a, Show b) => Int -> f a b -> ShowS
showsPrec2 = showsPrecWith2 showsPrec showsPrec

-- | The @String@ 'Show1' instance for 'FromTextShow1' is based on its
-- 'TextShow1' instance. That is,
--
-- @
-- showsPrecWith sp p ('FromTextShow1' x) =
--     'showbToShows' ('showbPrecWith' ('showsToShowb' sp)) p x
-- @
--
-- /Since: ?.?/
newtype FromTextShow1 f a = FromTextShow1 { fromTextShow1 :: f a }
  deriving ( Eq
           , Functor
           , Foldable
#if __GLASGOW_HASKELL__ >= 702
           , Generic
# if __GLASGOW_HASKELL__ >= 706
           , Generic1
# endif
#endif
           , Ord
           , TextShow1
           , Traversable
#if __GLASGOW_HASKELL__ >= 708
           , Data
           , Typeable
#endif
           )

instance Read (f a) => Read (FromTextShow1 f a) where
    readPrec = FromTextShow1 <$> readPrec
    INLINE_INST_FUN(readPrec)

    readListPrec = readListPrecDefault
    INLINE_INST_FUN(readListPrec)

instance (TextShow1 f, TextShow a) => Show (FromTextShow1 f a) where
    showsPrec = showsPrecWith (showbToShows showbPrec)
    INLINE_INST_FUN(showsPrec)

instance TextShow1 f => Show1 (FromTextShow1 f) where
    showsPrecWith sp p =
        showbToShows (showbPrecWith $ showsToShowb sp) p . fromTextShow1
    INLINE_INST_FUN(showsPrecWith)

instance (TextShow1 f, TextShow a) => TextShow (FromTextShow1 f a) where
    showbPrec = showbPrec1
    INLINE_INST_FUN(showbPrec)

-- | The 'TextShow2' instance for 'FromStringShow2' is based on its @String@
-- 'Show2' instance. That is,
--
-- @
-- showbPrecWith2 sp1 sp2 p ('FromStringShow2' x) =
--     'showsToShowb' ('showsPrecWith2' ('showbToShows' sp1) ('showbToShows' sp2)) p x
-- @
--
-- /Since: ?.?/
newtype FromStringShow2 f a b = FromStringShow2 { fromStringShow2 :: f a b }
  deriving ( Eq
           , Functor
           , Foldable
#if __GLASGOW_HASKELL__ >= 702
           , Generic
# if defined(__LANGUAGE_DERIVE_GENERIC1__)
           , Generic1
# endif
#endif
           , Ord
           , Show2
           , Traversable
#if __GLASGOW_HASKELL__ >= 708
           , Data
           , Typeable
#endif
           )

instance Bifunctor f => Bifunctor (FromStringShow2 f) where
    bimap f g = FromStringShow2 . bimap f g . fromStringShow2
    INLINE_INST_FUN(bimap)

instance Read (f a b) => Read (FromStringShow2 f a b) where
    readPrec = FromStringShow2 <$> readPrec
    INLINE_INST_FUN(readPrec)

    readListPrec = readListPrecDefault
    INLINE_INST_FUN(readListPrec)

instance (Show2 f, Show a, Show b) => TextShow (FromStringShow2 f a b) where
    showbPrec = showbPrecWith (showsToShowb showsPrec)
    INLINE_INST_FUN(showbPrec)

instance (Show2 f, Show a) => TextShow1 (FromStringShow2 f a) where
    showbPrecWith = showbPrecWith2 (showsToShowb showsPrec)
    INLINE_INST_FUN(showbPrecWith)

instance Show2 f => TextShow2 (FromStringShow2 f) where
    showbPrecWith2 sp1 sp2 p =
        showsToShowb (showsPrecWith2 (showbToShows sp1) (showbToShows sp2)) p . fromStringShow2
    INLINE_INST_FUN(showbPrecWith2)

instance (Show2 f, Show a, Show b) => Show (FromStringShow2 f a b) where
    showsPrec = showsPrec2
    INLINE_INST_FUN(showsPrec)

instance (Show2 f, Show a) => Show1 (FromStringShow2 f a) where
    showsPrecWith = showsPrecWith2 showsPrec
    INLINE_INST_FUN(showsPrecWith)

-- | The @String@ 'Show2' instance for 'FromTextShow2' is based on its
-- 'TextShow2' instance. That is,
--
-- @
-- showsPrecWith2 sp1 sp2 p ('FromTextShow2' x) =
--     'showbToShows' ('showbPrecWith2' ('showsToShowb' sp1) ('showsToShowb' sp2)) p x
-- @
--
-- /Since: ?.?/
newtype FromTextShow2 f a b = FromTextShow2 { fromTextShow2 :: f a b }
  deriving ( Eq
           , Functor
           , Foldable
#if __GLASGOW_HASKELL__ >= 702
           , Generic
# if defined(__LANGUAGE_DERIVE_GENERIC1__)
           , Generic1
# endif
#endif
           , Ord
           , TextShow2
           , Traversable
#if __GLASGOW_HASKELL__ >= 708
           , Data
           , Typeable
#endif
           )

instance Bifunctor f => Bifunctor (FromTextShow2 f) where
    bimap f g = FromTextShow2 . bimap f g . fromTextShow2
    INLINE_INST_FUN(bimap)

instance Read (f a b) => Read (FromTextShow2 f a b) where
    readPrec = FromTextShow2 <$> readPrec
    INLINE_INST_FUN(readPrec)

    readListPrec = readListPrecDefault
    INLINE_INST_FUN(readListPrec)

instance (TextShow2 f, TextShow a, TextShow b) => Show (FromTextShow2 f a b) where
    showsPrec = showsPrecWith (showbToShows showbPrec)
    INLINE_INST_FUN(showsPrec)

instance (TextShow2 f, TextShow a) => Show1 (FromTextShow2 f a) where
    showsPrecWith = showsPrecWith2 (showbToShows showbPrec)
    INLINE_INST_FUN(showsPrecWith)

instance TextShow2 f => Show2 (FromTextShow2 f) where
    showsPrecWith2 sp1 sp2 p =
        showbToShows (showbPrecWith2 (showsToShowb sp1) (showsToShowb sp2)) p . fromTextShow2
    INLINE_INST_FUN(showsPrecWith2)

instance (TextShow2 f, TextShow a, TextShow b) => TextShow (FromTextShow2 f a b) where
    showbPrec = showbPrec2
    INLINE_INST_FUN(showbPrec)

instance (TextShow2 f, TextShow a) => TextShow1 (FromTextShow2 f a) where
    showbPrecWith = showbPrecWith2 showbPrec
    INLINE_INST_FUN(showbPrecWith)

-------------------------------------------------------------------------------

-- | @'showsUnaryWith' sp n d x@ produces the string representation of a
-- unary data constructor with name @n@ and argument @x@, in precedence
-- context @d@.
showsUnaryWith :: (Int -> a -> ShowS) -> String -> Int -> a -> ShowS
showsUnaryWith sp name d x = showParen (d > 10) $
    showString name . showChar ' ' . sp 11 x

-- | @'showsBinaryWith' sp1 sp2 n d x y@ produces the string
-- representation of a binary data constructor with name @n@ and arguments
-- @x@ and @y@, in precedence context @d@.
showsBinaryWith :: (Int -> a -> ShowS) -> (Int -> b -> ShowS) ->
    String -> Int -> a -> b -> ShowS
showsBinaryWith sp1 sp2 name d x y = showParen (d > 10) $
    showString name . showChar ' ' . sp1 11 x . showChar ' ' . sp2 11 y

-------------------------------------------------------------------------------

instance Show a => Show1 ((,) a) where
    showsPrecWith = showsPrecWith2 showsPrec

instance Show a => Show1 (Either a) where
    showsPrecWith = showsPrecWith2 showsPrec

instance Show a => Show1 (Const a) where
    showsPrecWith = showsPrecWith2 showsPrec

instance Show1 Maybe where
    showsPrecWith _  _ Nothing  = showString "Nothing"
    showsPrecWith sp d (Just x) = showsUnaryWith sp "Just" d x

instance Show1 [] where
    showsPrecWith _  _ []     = showString "[]"
    showsPrecWith sp _ (x:xs) = showChar '[' . sp 0 x . showl xs
      where
        showl []     = showChar ']'
        showl (y:ys) = showChar ',' . sp 0 y . showl ys

instance Show1 Identity where
    showsPrecWith sp d (Identity x) = showsUnaryWith sp "Identity" d x

instance Show2 (,) where
    showsPrecWith2 sp1 sp2 _ (x, y) =
        showChar '(' . sp1 0 x . showChar ',' . sp2 0 y . showChar ')'

instance Show2 Either where
    showsPrecWith2 sp1 _   d (Left x)  = showsUnaryWith sp1 "Left" d x
    showsPrecWith2 _   sp2 d (Right x) = showsUnaryWith sp2 "Right" d x

instance Show2 Const where
    showsPrecWith2 sp _ d (Const x) = showsUnaryWith sp "Const" d x

instance (Show a, Show b, Show c) => Show2 ((,,,,) a b c) where
    showsPrecWith2 sp1 sp2 _ (a, b, c, d, e) =
        showChar '(' . shows a . showChar ','
                     . shows b . showChar ','
                     . shows c . showChar ','
                     . sp1 0 d . showChar ','
                     . sp2 0 e . showChar ')'

-- TODO: Move these instance into text-show itself once transformers is updated
instance Show1 FromStringShow where
    showsPrecWith sp p = sp p . fromStringShow
    INLINE_INST_FUN(showsPrecWith)

instance Show1 FromTextShow where
    showsPrecWith sp p =
        showbToShows (showsToShowb sp) p . fromTextShow
    INLINE_INST_FUN(showsPrecWith)

-------------------------------------------------------------------------------

#if __GLASGOW_HASKELL__ < 702
$(Generics.deriveAll ''FromStringShow1)
$(Generics.deriveAll ''FromStringShow2)
#endif