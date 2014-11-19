{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Text.Show.Text.Data.Bool
-- Copyright   :  (C) 2014 Ryan Scott
-- License     :  BSD-style (see the file LICENSE)
-- Maintainer  :  Ryan Scott
-- Stability   :  Experimental
-- Portability :  GHC
-- 
-- Monomorphic 'Show' functions for 'Bool' values.
----------------------------------------------------------------------------
module Text.Show.Text.Data.Bool (showbBool) where

import Data.Text.Buildable (build)
import Data.Text.Lazy.Builder (Builder)

import Prelude hiding (Show)

import Text.Show.Text.Class (Show(showb))

-- | Convert a 'Bool' to a 'Builder'.
showbBool :: Bool -> Builder
showbBool = build
{-# INLINE showbBool #-}

instance Show Bool where
    showb = showbBool
    {-# INLINE showb #-}