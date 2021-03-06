{-# LANGUAGE CPP           #-}
{-# LANGUAGE TypeFamilies  #-}
{-# LANGUAGE TypeOperators #-}

#if __GLASGOW_HASKELL__ >= 706
{-# LANGUAGE PolyKinds #-}
#endif

{-# OPTIONS_GHC -fno-warn-orphans #-}

{-|
Module:      Instances.Data.Type.Equality
Copyright:   (C) 2014-2016 Ryan Scott
License:     BSD-style (see the file LICENSE)
Maintainer:  Ryan Scott
Stability:   Provisional
Portability: GHC

'Arbitrary' instance for '(:~:)'.
-}
module Instances.Data.Type.Equality () where

#if MIN_VERSION_base(4,7,0)
import Data.Type.Equality ((:~:)(..))

import Prelude ()
import Prelude.Compat

import Test.QuickCheck (Arbitrary(..))

instance a ~ b => Arbitrary (a :~: b) where
    arbitrary = pure Refl
#endif
