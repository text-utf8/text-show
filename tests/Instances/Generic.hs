{-# LANGUAGE CPP #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

{-|
Module:      Instances.Generic
Copyright:   (C) 2014-2015 Ryan Scott
License:     BSD-style (see the file LICENSE)
Maintainer:  Ryan Scott
Stability:   Experimental
Portability: GHC

'Arbitrary' instance for 'ConType'.
-}
module Instances.Generic () where

#if __GLASGOW_HASKELL__ >= 702
import Instances.Data.Text ()

import Prelude ()
import Prelude.Compat

import Test.QuickCheck (Arbitrary(..), oneof)

import Text.Show.Text.Generic (ConType(..))

instance Arbitrary ConType where
    arbitrary = oneof [pure Rec, pure Tup, pure Pref, Inf <$> arbitrary]
#endif