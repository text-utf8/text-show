{-# LANGUAGE FlexibleContexts #-}

{-|
Module:      TextShow.Debug.Trace.Generic
Copyright:   (C) 2014-2016 Ryan Scott
License:     BSD-style (see the file LICENSE)
Maintainer:  Ryan Scott
Stability:   Provisional
Portability: GHC

Functions that trace the values of 'Generic' instances (even if they are not
instances of @TextShow@).

/Since: 2/
-}
module TextShow.Debug.Trace.Generic (
      genericTraceTextShow
    , genericTraceTextShowId
    , genericTraceTextShowM
    ) where

import Generics.Deriving.Base (Generic, Rep)

import Prelude ()
import Prelude.Compat

import TextShow.Debug.Trace
import TextShow.Generic (GTextShow, Zero, genericShowt)

-- | A 'Generic' implementation of 'traceTextShow'.
--
-- /Since: 2/
genericTraceTextShow :: (Generic a, GTextShow Zero (Rep a)) => a -> b -> b
genericTraceTextShow = tracet . genericShowt

-- | A 'Generic' implementation of 'traceTextShowId'.
--
-- /Since: 2/
genericTraceTextShowId :: (Generic a, GTextShow Zero (Rep a)) => a -> a
genericTraceTextShowId a = tracet (genericShowt a) a

-- | A 'Generic' implementation of 'traceShowM'.
--
-- /Since: 2/
genericTraceTextShowM :: (Generic a, GTextShow Zero (Rep a), Applicative f) => a -> f ()
genericTraceTextShowM = tracetM . genericShowt
