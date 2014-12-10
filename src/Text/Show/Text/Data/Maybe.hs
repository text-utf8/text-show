{-# LANGUAGE NoImplicitPrelude, TemplateHaskell #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-|
Module:      Text.Show.Text.Data.Maybe
Copyright:   (C) 2014 Ryan Scott
License:     BSD-style (see the file LICENSE)
Maintainer:  Ryan Scott
Stability:   Experimental
Portability: GHC

Monomorphic 'Show' function for 'Maybe' values.
-}
module Text.Show.Text.Data.Maybe (showbMaybePrec) where

import Data.Text.Lazy.Builder (Builder)

import Prelude hiding (Show)

import Text.Show.Text.Classes (Show(showbPrec), Show1(showbPrec1))
import Text.Show.Text.TH.Internal (deriveShow)

-- | Convert a 'Maybe' value to a 'Builder' with the given precedence.
showbMaybePrec :: Show a => Int -> Maybe a -> Builder
showbMaybePrec = showbPrec
{-# INLINE showbMaybePrec #-}

$(deriveShow ''Maybe)

instance Show1 Maybe where
    showbPrec1 = showbPrec
    {-# INLINE showbPrec1 #-}