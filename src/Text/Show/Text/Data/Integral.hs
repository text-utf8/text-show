{-# LANGUAGE CPP, MagicHash, OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-|
Module:      Text.Show.Text.Data.Integral
Copyright:   (C) 2014-2015 Ryan Scott
License:     BSD-style (see the file LICENSE)
Maintainer:  Ryan Scott
Stability:   Experimental
Portability: GHC

Monomorphic 'Show' functions for integral types.

/Since: 0.3/
-}
module Text.Show.Text.Data.Integral (
      showbIntPrec
    , showbInt8Prec
    , showbInt16Prec
    , showbInt32Prec
    , showbInt64Prec
    , showbIntegerPrec
    , showbIntegralPrec
    , showbIntAtBase
    , showbBin
    , showbHex
    , showbOct
    , showbWord
    , showbWord8
    , showbWord16
    , showbWord32
    , showbWord64
    ) where

import           Data.Char (intToDigit)
import           Data.Int (Int8, Int16, Int32, Int64)
#if !(MIN_VERSION_base(4,8,0))
import           Data.Monoid (mempty)
#endif
import           Data.Text.Lazy.Builder (Builder)
import           Data.Text.Lazy.Builder.Int (decimal)
import           Data.Word ( Word8
                           , Word16
                           , Word32
                           , Word64
#if !(MIN_VERSION_base(4,8,0))
                           , Word
#endif
                           )

import           GHC.Exts (Int(I#))
#if __GLASGOW_HASKELL__ >= 708
import           GHC.Exts (isTrue#)
import           GHC.Prim (Int#)
#endif
import           GHC.Prim ((<#), (>#))

import           Prelude hiding (Show)

import           Text.Show.Text.Classes (Show(showb, showbPrec))
import           Text.Show.Text.Utils ((<>), s, toString)

#include "inline.h"

-- | Convert an 'Int' to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbIntPrec :: Int -> Int -> Builder
showbIntPrec (I# p) n'@(I# n)
    | isTrue (n <# 0#) && isTrue (p ># 6#) = s '(' <> decimal n' <> s ')'
    | otherwise = decimal n'
  where
#if __GLASGOW_HASKELL__ >= 708
      isTrue :: Int# -> Bool
      isTrue b = isTrue# b
#else
      isTrue :: Bool -> Bool
      isTrue = id
#endif

-- | Convert an 'Int8' to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbInt8Prec :: Int -> Int8 -> Builder
showbInt8Prec p = showbIntPrec p . fromIntegral
{-# INLINE showbInt8Prec #-}

-- | Convert an 'Int16' to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbInt16Prec :: Int -> Int16 -> Builder
showbInt16Prec p = showbIntPrec p . fromIntegral
{-# INLINE showbInt16Prec #-}

-- | Convert an 'Int32' to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbInt32Prec :: Int -> Int32 -> Builder
showbInt32Prec p = showbIntPrec p . fromIntegral
{-# INLINE showbInt32Prec #-}

-- | Convert an 'Int64' to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbInt64Prec :: Int -> Int64 -> Builder
#if WORD_SIZE_IN_BITS < 64
showbInt64Prec p = showbIntegerPrec p . toInteger
#else
showbInt64Prec p = showbIntPrec p . fromIntegral
#endif
{-# INLINE showbInt64Prec #-}

-- | Convert an 'Integer' to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbIntegerPrec :: Int -> Integer -> Builder
showbIntegerPrec p n
    | p > 6 && n < 0 = s '(' <> decimal n <> s ')'
    | otherwise      = decimal n
{-# INLINE showbIntegerPrec #-}

-- | Convert an 'Integral' type to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbIntegralPrec :: Integral a => Int -> a -> Builder
showbIntegralPrec p = showbIntegerPrec p . toInteger
{-# INLINE showbIntegralPrec #-}

-- | Shows a /non-negative/ 'Integral' number using the base specified by the
-- first argument, and the character representation specified by the second.
-- 
-- /Since: 0.3/
showbIntAtBase :: (Integral a, Show a) => a -> (Int -> Char) -> a -> Builder
showbIntAtBase base toChr n0
    | base <= 1 = error . toString $ "Text.Show.Text.Int.showbIntAtBase: applied to unsupported base" <> showb base
    | n0 < 0    = error . toString $ "Text.Show.Text.Int.showbIntAtBase: applied to negative number " <> showb n0
    | otherwise = showbIt (quotRem n0 base) mempty
  where
    showbIt (n, d) b = seq c $ -- stricter than necessary
        case n of
             0 -> b'
             _ -> showbIt (quotRem n base) b'
      where
        c :: Char
        c = toChr $ fromIntegral d
        
        b' :: Builder
        b' = s c <> b

-- | Show /non-negative/ 'Integral' numbers in base 2.
-- 
-- /Since: 0.3/
showbBin :: (Integral a, Show a) => a -> Builder
showbBin = showbIntAtBase 2 intToDigit
{-# INLINE showbBin #-}

-- | Show /non-negative/ 'Integral' numbers in base 16.
-- 
-- /Since: 0.3/
showbHex :: (Integral a, Show a) => a -> Builder
showbHex = showbIntAtBase 16 intToDigit
{-# INLINE showbHex #-}

-- | Show /non-negative/ 'Integral' numbers in base 8.
-- 
-- /Since: 0.3/
showbOct :: (Integral a, Show a) => a -> Builder
showbOct = showbIntAtBase 8 intToDigit
{-# INLINE showbOct #-}

-- | Convert a 'Word' to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbWord :: Word -> Builder
showbWord = decimal
{-# INLINE showbWord #-}

-- | Convert a 'Word8' to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbWord8 :: Word8 -> Builder
showbWord8 = decimal
{-# INLINE showbWord8 #-}

-- | Convert a 'Word16' to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbWord16 :: Word16 -> Builder
showbWord16 = decimal
{-# INLINE showbWord16 #-}

-- | Convert a 'Word32' to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbWord32 :: Word32 -> Builder
showbWord32 = decimal
{-# INLINE showbWord32 #-}

-- | Convert a 'Word64' to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3/
showbWord64 :: Word64 -> Builder
showbWord64 = decimal
{-# INLINE showbWord64 #-}

instance Show Int where
    showbPrec = showbIntPrec
    INLINE_INST_FUN(showbPrec)

instance Show Int8 where
    showbPrec = showbInt8Prec
    INLINE_INST_FUN(showbPrec)

instance Show Int16 where
    showbPrec = showbInt16Prec
    INLINE_INST_FUN(showbPrec)

instance Show Int32 where
    showbPrec = showbInt32Prec
    INLINE_INST_FUN(showbPrec)

instance Show Int64 where
    showbPrec = showbInt64Prec
    INLINE_INST_FUN(showbPrec)

instance Show Integer where
    showbPrec = showbIntegerPrec
    INLINE_INST_FUN(showbPrec)

instance Show Word where
    showb = showbWord
    INLINE_INST_FUN(showb)

instance Show Word8 where
    showb = showbWord8
    INLINE_INST_FUN(showb)

instance Show Word16 where
    showb = showbWord16
    INLINE_INST_FUN(showb)

instance Show Word32 where
    showb = showbWord32
    INLINE_INST_FUN(showb)

instance Show Word64 where
    showb = showbWord64
    INLINE_INST_FUN(showb)
