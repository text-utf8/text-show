{-# LANGUAGE CPP, TemplateHaskell #-}
{-|
Module:      Text.Show.Text.TH.Internal
Copyright:   (C) 2014-2015 Ryan Scott
License:     BSD-style (see the file LICENSE)
Maintainer:  Ryan Scott
Stability:   Experimental
Portability: GHC

Functions to mechanically derive 'T.Show' instances or splice
@show@-related expressions into Haskell source code. You need to enable
the @TemplateHaskell@ language extension in order to use this module.

This implementation is based off of the @Data.Aeson.TH@ module from the
@aeson@ library.
-}
module Text.Show.Text.TH.Internal (
      -- * @deriveShow@
      -- $deriveShow
      deriveShow
    , deriveShowPragmas
      -- * @mk@ functions
      -- $mk
    , mkShow
    , mkShowLazy
    , mkShowPrec
    , mkShowPrecLazy
    , mkShowList
    , mkShowListLazy
    , mkShowb
    , mkShowbPrec
    , mkShowbList
    , mkPrint
    , mkPrintLazy
    , mkHPrint
    , mkHPrintLazy
      -- * Advanced pragma options
    , PragmaOptions(..)
    , defaultPragmaOptions
    , defaultInlineShowbPrec
    , defaultInlineShowb
    , defaultInlineShowbList
    ) where

import           Data.Functor ((<$>))
import           Data.List (foldl', find, intersperse)
import           Data.Maybe (fromJust)
#if !(MIN_VERSION_base(4,8,0))
import           Data.Monoid (mempty)
#endif
import qualified Data.Text    as TS ()
import qualified Data.Text.IO as TS (putStrLn, hPutStrLn)
import           Data.Text.Lazy (toStrict)
import           Data.Text.Lazy.Builder (fromString, toLazyText)
import qualified Data.Text.Lazy    as TL ()
import qualified Data.Text.Lazy.IO as TL (putStrLn, hPutStrLn)

import           GHC.Show (appPrec, appPrec1)

import           Language.Haskell.TH

import           Prelude hiding (Show)

import qualified Text.Show as S (Show(show))
import qualified Text.Show.Text.Classes as T (Show)
import           Text.Show.Text.Classes (showb, showbPrec, showbListDefault,
                                         showbParen, showbSpace)
#if __GLASGOW_HASKELL__ >= 702
import           Text.Show.Text.Classes (showbList)
#endif
import           Text.Show.Text.Utils ((<>), isInfixTypeCon, isTupleString, s)

{- $deriveShow

'deriveShow' automatically generates a 'T.Show' instance declaration for a @data@
type or @newtype@. As an example:

@
&#123;-&#35; LANGUAGE TemplateHaskell &#35;-&#125;
import Text.Show.Text.TH (deriveShow)

data D a = Nullary
         | Unary Int
         | Product String Char a
         | Record { testOne   :: Double
                  , testTwo   :: Bool
                  , testThree :: D a
                  }
$('deriveShow' ''D)
@

@D@ now has a 'T.Show' instance analogous to what would be generated by a
@deriving Show@ clause.

Note that at the moment, there are a number of limitations to this approach:

* 'deriveShow' does not support data families, so it is impossible to use
  'deriveShow' with @data instance@s or @newtype instance@s.
  
* 'deriveShow' lacks the ability to properly detect data types with higher-kinded
   type parameters (e.g., @data HK f a = HK (f a)@). If you wish to derive 'T.Show'
   instances for these data types, you will need to use 'mkShowbPrec' (see the
   documentation of the 'mk' functions for more information).

* Some data constructors have arguments whose 'T.Show' instance depends on a
  typeclass besides 'T.Show'. For example, consider @newtype MyRatio a = MyRatio
  (Ratio a)@. @'Ratio' a@ is a 'T.Show' instance only if @a@ is an instance of both
  'Integral' and 'T.Show'. Unfortunately, 'deriveShow' cannot infer that 'a' must
  be an instance of 'Integral', so it cannot create a 'T.Show' instance for @MyRatio@.
  However, you can use 'mkShowbPrec' to get around this (see the documentation of the
  'mk' functions for more information).

-}

-- | Generates a 'T.Show' instance declaration for the given @data@ type or @newtype@.
-- 
-- /Since: 0.3/
deriveShow :: Name -- ^ Name of the data type to make an instance of 'T.Show'
           -> Q [Dec]
deriveShow = deriveShowPragmas defaultPragmaOptions

-- | Generates a 'T.Show' instance declaration for the given @data@ type or @newtype@.
-- You shouldn't need to use this function unless you know what you are doing.
-- 
-- Unlike 'deriveShow', this function allows configuration of whether to inline
-- 'showbPrec', 'showb', or 'showbList'. It also allows for specializing instances
-- certain types. For example:
-- 
-- @
-- data ADT a = ADT a
-- $(deriveShowPragmas 'defaultInlineShowbPrec' {
--                         specializeTypes = [t| Int |]
--                      }
--                      ''ADT)
-- @
-- 
-- This declararation would produce code like this:
-- 
-- @
-- instance Show a => Show (ADT a) where
--     &#123;-&#35; INLINE showbPrec &#35;-&#125;
--     &#123;-&#35; SPECIALIZE instance Show (ADT Int) &#35;-&#125;
--     showbPrec = ...
-- @
-- 
-- /Since: 0.5/
deriveShowPragmas :: PragmaOptions -- ^ Specifies what pragmas to generate with this instance
                  -> Name          -- ^ Name of the data type to make an instance of 'T.Show'
                  -> Q [Dec]
deriveShowPragmas opts name = do
    info <- reify name
    case info of
        TyConI{} -> deriveShowTyCon opts name
#if MIN_VERSION_template_haskell(2,7,0)
        DataConI{} -> deriveShowDataFamInst opts name
        FamilyI (FamilyD DataFam _ _ _) _ -> deriveShowDataFam opts name
        FamilyI (FamilyD TypeFam _ _ _) _ -> error $ ns ++ "Cannot use a type family name."
        -- TODO: Figure out how this whole multiline string business works
        _ -> error $ ns ++ "The name must be of a plain type constructor, data family, or data family instance constructor."
#else
        _ -> error $ ns ++ "The name must be of a plain type constructor."
#endif
  where
    ns :: String
    ns = "Text.Show.Text.TH.deriveShow: "

deriveShowTyCon :: PragmaOptions
                -> Name
                -> Q [Dec]
deriveShowTyCon opts tyConName = withTyCon tyConName fromCons
  where
    fromCons :: [TyVarBndr] -> [Con] -> Q [Dec]
    fromCons tvbs cons = (:[]) <$>
        instanceD (applyCon ''T.Show typeNames)
                  (appT (conT ''T.Show) instanceType)
                  (showbPrecDecs opts cons)
      where
        typeNames :: [Name]
        typeNames = map tvbName tvbs
        
        instanceType :: Q Type
        instanceType = foldl' appT (conT tyConName) $ map varT typeNames

#if MIN_VERSION_template_haskell(2,7,0)
deriveShowDataFam :: PragmaOptions
                  -> Name
                  -> Q [Dec]
deriveShowDataFam opts dataFamName = withDataFam dataFamName $ \tvbs decs ->
    flip mapM decs $ deriveShowDataFamFromDec opts dataFamName tvbs

deriveShowDataFamInst :: PragmaOptions
                      -> Name
                      -> Q [Dec]
deriveShowDataFamInst opts dataFamInstName = (:[]) <$>
    withDataFamInstCon dataFamInstName (deriveShowDataFamFromDec opts)

deriveShowDataFamFromDec :: PragmaOptions
                         -> Name
                         -> [TyVarBndr]
                         -> Dec
                         -> Q Dec
deriveShowDataFamFromDec opts parentName tvbs dec =
    instanceD (applyCon ''T.Show lhsTypeNames)
              (appT (conT ''T.Show) instanceType)
              (showbPrecDecs opts $ decCons [dec])
  where
    typeNames :: [Name]
    typeNames = map tvbName tvbs
    
    lhsTypeNames :: [Name]
    lhsTypeNames = drop (length instTypes) typeNames
    
    rhsTypes :: [Type]
    rhsTypes = instTypes ++ drop (length instTypes) (map VarT typeNames)
    
    instTypes :: [Type]
    instTypes = let tys = case dec of
                              DataInstD    _ _ tys' _ _ -> tys'
                              NewtypeInstD _ _ tys' _ _ -> tys'
                              _ -> error "Text.Show.Text.TH.deriveShow: The impossible happened."
                -- If PolyKinds is enabled, the first entries in this list will be
                -- kind signatures, so drop them
                in if length tys > length tvbs
                      then drop (length tvbs) tys
                      else tys
    
    instanceType :: Q Type
    instanceType = foldl' appT (conT parentName) $ map return rhsTypes
#endif

{- $mk

There may be scenarios in which you want to show an arbitrary @data@ type or @newtype@
without having to make the type an instance of 'T.Show'. For these cases,
"Text.Show.Text.TH" provide several functions (all prefixed with @mk@) that splice
the appropriate lambda expression into your source code.

As an example, suppose you have @data ADT = ADTCon@, which is not an instance of 'T.Show'.
With @mkShow@, you can still convert it to 'Text':

@
&#123;-&#35; LANGUAGE OverloadedStrings, TemplateHaskell &#35;-&#125;

whichADT :: Bool
whichADT = $(mkShow ''ADT) ADTCon == \"ADT\"
@

'mk' functions are also useful for creating 'T.Show' instances for data types with
sophisticated type parameters. For example, 'deriveShow' cannot infer the correct type
context for @newtype HigherKinded f a = HigherKinded (f a)@, since @f@ is a
higher-kinded type parameter. However, it is still possible to derive a 'T.Show'
instance for @HigherKinded@ without too much trouble using 'mkShowbPrec':

@
&#123;-&#35; LANGUAGE TemplateHaskell &#35;-&#125;

instance Show (f a) => Show (HigherKinded f a) where
    showbPrec = $(mkShowbPrec ''HigherKinded)
@

-}

-- | Generates a lambda expression which converts the given @data@ type or @newtype@
-- to a strict 'TS.Text'.
-- 
-- /Since: 0.3.1/
mkShow :: Name -> Q Exp
mkShow name = [| toStrict . $(mkShowLazy name) |]

-- | Generates a lambda expression which converts the given @data@ type or @newtype@
-- to a lazy 'TL.Text'.
-- 
-- /Since: 0.3.1/
mkShowLazy :: Name -> Q Exp
mkShowLazy name = [| toLazyText . $(mkShowb name) |]

-- | Generates a lambda expression which converts the given @data@ type or @newtype@
-- to a strict 'TS.Text' with the given precedence.
-- 
-- /Since: 0.3.1/
mkShowPrec :: Name -> Q Exp
mkShowPrec name = [| \p -> toStrict . $(mkShowPrecLazy name) p |]

-- | Generates a lambda expression which converts the given @data@ type or @newtype@
-- to a lazy 'TL.Text' with the given precedence.
-- 
-- /Since: 0.3.1/
mkShowPrecLazy :: Name -> Q Exp
mkShowPrecLazy name = [| \p -> toLazyText . $(mkShowbPrec name) p |]

-- | Generates a lambda expression which converts the given list of @data@ types or
-- @newtype@s to a strict 'TS.Text' in which the values are surrounded by square
-- brackets and each value is separated by a comma.
-- 
-- /Since: 0.5/
mkShowList :: Name -> Q Exp
mkShowList name = [| toStrict . $(mkShowListLazy name) |]

-- | Generates a lambda expression which converts the given list of @data@ types or
-- @newtype@s to a lazy 'TL.Text' in which the values are surrounded by square
-- brackets and each value is separated by a comma.
-- 
-- /Since: 0.5/
mkShowListLazy :: Name -> Q Exp
mkShowListLazy name = [| toLazyText . $(mkShowbList name) |]

-- | Generates a lambda expression which converts the given @data@ type or @newtype@
-- to a 'Builder'.
-- 
-- /Since: 0.3.1/
mkShowb :: Name -> Q Exp
mkShowb name = mkShowbPrec name `appE` [| 0 :: Int |]

-- | Generates a lambda expression which converts the given @data@ type or @newtype@
-- to a 'Builder' with the given precedence.
-- 
-- /Since: 0.3.1/
mkShowbPrec :: Name -> Q Exp
-- TODO: This will break once data families are added. Rework the 'withTyCon' part.
mkShowbPrec name = do
    info <- reify name
    case info of
        TyConI{} -> withTyCon name $ \_ decs -> consToShow decs
#if MIN_VERSION_template_haskell(2,7,0)
        DataConI{} -> withDataFamInstCon name $ \_ _ dec ->
            consToShow $ decCons [dec]
        FamilyI (FamilyD DataFam _ _ _) _ -> withDataFam name $ \_ decs ->
            consToShow $ decCons decs
        FamilyI (FamilyD TypeFam _ _ _) _ -> error $ ns ++ "Cannot use a type family name."
        -- TODO: Figure out how this whole multiline string business works
        _ -> error $ ns ++ "The name must be of a plain type constructor, data family, or data family instance constructor."
#else
        _ -> error $ ns ++ "The name must be of a plain type constructor."
#endif
  where
    ns :: String
    ns = "Text.Show.Text.TH.mk: "

-- | Generates a lambda expression which converts the given list of @data@ types or
-- @newtype@s to a 'Builder' in which the values are surrounded by square brackets
-- and each value is separated by a comma.
-- 
-- /Since: 0.5/
mkShowbList :: Name -> Q Exp
mkShowbList name = [| showbListDefault $(mkShowb name) |]

-- | Generates a lambda expression which writes the given @data@ type or @newtype@
-- argument's strict 'TS.Text' output to the standard output, followed by a newline.
-- 
-- /Since: 0.3.1/
mkPrint :: Name -> Q Exp
mkPrint name = [| TS.putStrLn . $(mkShow name) |]

-- | Generates a lambda expression which writes the given @data@ type or @newtype@
-- argument's lazy 'TL.Text' output to the standard output, followed by a newline.
-- 
-- /Since: 0.3.1/
mkPrintLazy :: Name -> Q Exp
mkPrintLazy name = [| TL.putStrLn . $(mkShowLazy name) |]

-- | Generates a lambda expression which writes the given @data@ type or @newtype@
-- argument's strict 'TS.Text' output to the given file handle, followed by a newline.
-- 
-- /Since: 0.3.1/
mkHPrint :: Name -> Q Exp
mkHPrint name = [| \h -> TS.hPutStrLn h . $(mkShow name) |]

-- | Generates a lambda expression which writes the given @data@ type or @newtype@
-- argument's lazy 'TL.Text' output to the given file handle, followed by a newline.
-- 
-- /Since: 0.3.1/
mkHPrintLazy :: Name -> Q Exp
mkHPrintLazy name = [| \h -> TL.hPutStrLn h . $(mkShowLazy name) |]

-- | Options that specify what @INLINE@ or @SPECIALIZE@ pragmas to generate with
-- a 'T.Show' instance.
-- 
-- /Since: 0.5/
data PragmaOptions = PragmaOptions {
    inlineShowbPrec  :: Bool    -- ^ Whether to inline 'showbPrec'
  , inlineShowb      :: Bool    -- ^ Whether to inline 'showb'
  , inlineShowbList  :: Bool    -- ^ Whether to inline 'showbList'
  , specializeTypes :: [Q Type] -- ^ Types for which to create specialized instance declarations
}

-- | Do not generate any pragmas with a 'T.Show' instance.
-- 
-- /Since: 0.5/
defaultPragmaOptions :: PragmaOptions
defaultPragmaOptions = PragmaOptions False False False []

-- | Inline the 'showbPrec' function in a 'T.Show' instance.
-- 
-- /Since: 0.5/
defaultInlineShowbPrec :: PragmaOptions
defaultInlineShowbPrec = defaultPragmaOptions { inlineShowbPrec = True }

-- | Inline the 'showb' function in a 'T.Show' instance.
-- 
-- /Since: 0.5/
defaultInlineShowb :: PragmaOptions
defaultInlineShowb = defaultPragmaOptions { inlineShowb = True }

-- | Inline the 'showbList' function in a 'T.Show' instance.
-- 
-- /Since: 0.5/
defaultInlineShowbList :: PragmaOptions
defaultInlineShowbList = defaultPragmaOptions { inlineShowbList = True }

-- | Generates code to generate the 'T.Show' encoding of a number of constructors.
-- All constructors must be from the same type.
consToShow :: [Con] -> Q Exp
consToShow []   = error $ "Text.Show.Text.TH.consToShow: Not a single constructor given!"
consToShow cons = do
    p     <- newName "p"
    value <- newName "value"
    lam1E (varP p)
        . lam1E (varP value)
        . caseE (varE value)
        $ map (encodeArgs p) cons

-- | Generates code to generate the 'T.Show' encoding of a single constructor.
encodeArgs :: Name -> Con -> Q Match
encodeArgs p (NormalC conName [])
    = match (conP conName [])
            (normalB [| intConst (fromString $(stringE (nameBase conName))) $(varE p) |])
            []
encodeArgs p (NormalC conName [_]) = do
    arg <- newName "arg"
    
    let showArg  = [| showbPrec appPrec1 $(varE arg) |]
        namedArg = [| fromString $(stringE (nameBase conName)) <> showbSpace <> $(showArg) |] 
    
    match (conP conName [varP arg])
          (normalB [| showbParen ($(varE p) > appPrec) $(namedArg) |])
          []
encodeArgs p (NormalC conName ts) = do
    args <- mapM newName ["arg" ++ S.show n | (_, n) <- zip ts [1 :: Int ..]]
    
    if isNonUnitTuple conName
       then do
           let showArgs       = map (appE [| showb |] . varE) args
               parenCommaArgs = [| s '(' |] : intersperse [| s ',' |] showArgs
               mappendArgs    = foldr (flip infixApp [| (<>) |])
                                      [| s ')' |]
                                      parenCommaArgs
           
           match (conP conName $ map varP args)
                 (normalB [| intConst $(mappendArgs) $(varE p) |])
                 []
       else do
           let showArgs = map (appE [| showbPrec appPrec1 |] . varE) args
               mappendArgs = foldr1 (\v q -> [| $(v) <> showbSpace <> $(q) |]) showArgs
               namedArgs   = [| fromString $(stringE (nameBase conName)) <> showbSpace <> $(mappendArgs) |]
           
           match (conP conName $ map varP args)
                 (normalB [| showbParen ($(varE p) > appPrec) $(namedArgs) |])
                 []
encodeArgs p (RecC conName []) = encodeArgs p $ NormalC conName []
encodeArgs p (RecC conName ts) = do
    args <- mapM newName ["arg" ++ S.show n | (_, n) <- zip ts [1 :: Int ..]]
    
    let showArgs       = concatMap (\(arg, (argName, _, _))
                                      -> [ [| fromString $(stringE (nameBase argName)) |]
                                         , [| fromString " = "                         |]
                                         , [| showb $(varE arg)                        |]
                                         , [| fromString ", "                          |]
                                         ]
                                   )
                                   (zip args ts)
        braceCommaArgs = [| s '{' |] : take (length showArgs - 1) showArgs
        mappendArgs    = foldr (flip infixApp [| (<>) |])
                           [| s '}' |]
                           braceCommaArgs
        namedArgs      = [| fromString $(stringE (nameBase conName)) <> showbSpace <> $(mappendArgs) |]
    
    match (conP conName $ map varP args)
          (normalB [| showbParen ($(varE p) > appPrec) $(namedArgs) |])
          []
encodeArgs p (InfixC _ conName _) = do
    al   <- newName "argL"
    ar   <- newName "argR"
    info <- reify conName
    
    let conPrec    = case info of
                       DataConI _ _ _ (Fixity prec _) -> prec
                       other -> error $ "Text.Show.Text.TH.encodeArgs: Unsupported type: " ++ S.show other
        opNameE    = stringE $ nameBase conName
        mBacktickE = [| if isInfixTypeCon $(opNameE)
                           then mempty
                           else s '`'
                     |]
    
    match (infixP (varP al) conName (varP ar))
          (normalB $ appE [| showbParen ($(varE p) > conPrec) |]
                          [| showbPrec (conPrec + 1) $(varE al)
                          <> showbSpace
                          <> $(mBacktickE)
                          <> fromString $(opNameE)
                          <> $(mBacktickE)
                          <> showbSpace
                          <> showbPrec (conPrec + 1) $(varE ar)
                          |]
          )
          []
encodeArgs p (ForallC _ _ con) = encodeArgs p con

-------------------------------------------------------------------------------
-- Utility functions
-------------------------------------------------------------------------------

-- | Checks if a 'Name' represents a tuple type constructor (other than '()')
isNonUnitTuple :: Name -> Bool
isNonUnitTuple = isTupleString . nameBase

-- | A type-restricted version of 'const'. This is useful when generating the lambda
-- expression in 'mkShowbPrec' for a data type with only nullary constructors (since
-- the expression wouldn't depend on the precedence). For example, if you had @data
-- Nullary = Nullary@ and attempted to run @$(mkShowbPrec ''Nullary) Nullary@, simply
-- ignoring the precedence argument would cause the type signature of @$(mkShowbPrec
-- ''Nullary)@ to be @a -> Nullary -> Builder@, not @Int -> Nullary -> Builder@.
-- 
-- To avoid this problem, after computing the 'Builder' @b@, we call @intConst b p@,
-- where @p@ is the precedence argument. This forces @p :: Int@.
intConst :: a -> Int -> a
intConst = const
{-# INLINE intConst #-}

-- | Boilerplate for top level splicing of plain type constructors.
-- 
-- The given 'Name' must be from a type constructor. Furthermore, the
-- type constructor must be either a data type or a newtype. Any other
-- value will result in an exception.
withTyCon :: Name -- ^ Name of the plain type constructor
            -> ([TyVarBndr] -> [Con] -> Q a)
            -- ^ Function that generates the actual code. Will be applied
            -- to the type variable binders and constructors extracted
            -- from the given 'Name'.
            -> Q a
            -- ^ Resulting value in the 'Q'uasi monad.
withTyCon name f = do
    info <- reify name
    case info of
        TyConI dec ->
            case dec of
                DataD    _ _ tvbs cons _ -> f tvbs cons
                NewtypeD _ _ tvbs con  _ -> f tvbs [con]
                other -> error $ ns ++ "Unsupported type " ++ S.show other ++ ". Must be a data type or newtype."
        _ -> error $ ns ++ "The name must be of a plain type constructor."
  where
    ns :: String
    ns = "Text.Show.Text.TH.withTyCon: "

#if MIN_VERSION_template_haskell(2,7,0)
withDataFam :: Name
            -> ([TyVarBndr] -> [Dec] -> Q a)
            -> Q a
withDataFam name f = do
    info <- reify name
    case info of
        FamilyI (FamilyD DataFam _ tvbs _) decs -> f tvbs decs
        FamilyI (FamilyD TypeFam _ _    _) _    ->
            error $ ns ++ "Cannot use a type family name."
        other -> error $ ns ++ "Unsupported type " ++ S.show other ++ ". Must be a data family name."
  where
    ns :: String
    ns = "Text.Show.Text.TH.withDataFam: "

withDataFamInstCon :: Name
                   -> (Name -> [TyVarBndr] -> Dec -> Q a)
                   -> Q a
withDataFamInstCon dficName f = do
    dficInfo <- reify dficName
    case dficInfo of
        DataConI _ _ parentName _ -> do
            parentInfo <- reify parentName
            case parentInfo of
                FamilyI (FamilyD DataFam _ _ _) _ -> withDataFam parentName $ \tvbs decs ->
                    let sameDefDec = fromJust . flip find decs $ \dec ->
                          case dec of
                              DataInstD    _ _ _ cons _ -> any ((dficName ==) . constructorName) cons 
                              NewtypeInstD _ _ _ con  _ -> dficName == constructorName con
                              _ -> error $ ns ++ "Must be a data or newtype instance."
                    in f parentName tvbs sameDefDec
                _ -> error $ ns ++ "Data constructor " ++ S.show dficName ++ " is not from a data family instance."
        other -> error $ ns ++ "Unsupported type " ++ S.show other ++ ". Must be a data family instance constructor."
  where
    ns :: String
    ns = "Text.Show.Text.TH.withDataFamInstCon: "
#endif

decCons :: [Dec] -> [Con]
decCons decs = flip concatMap decs $ \dec -> case dec of
    DataInstD    _ _ _ cons _ -> cons
    NewtypeInstD _ _ _ con  _ -> [con]
    _ -> error $ "Text.Show.Text.TH.decCons: Must be a data or newtype instance."

constructorName :: Con -> Name
constructorName (NormalC name      _  ) = name
constructorName (RecC    name      _  ) = name
constructorName (InfixC  _    name _  ) = name
constructorName (ForallC _    _    con) = constructorName con

-- | Extracts the name from a type variable binder.
tvbName :: TyVarBndr -> Name
tvbName (PlainTV  name  ) = name
tvbName (KindedTV name _) = name

-- | Applies a typeclass to several type parameters to produce the type predicate of
-- an instance declaration.
applyCon :: Name -> [Name] -> Q [Pred]
applyCon con typeNames = return $ map apply typeNames
  where
    apply :: Name -> Pred
    apply t =
#if MIN_VERSION_template_haskell(2,10,0)
        AppT (ConT con) (VarT t)
#else
        ClassP con [VarT t]
#endif

-- TODO: DEAR GOD LOOK AT ALL THE PRAGMAS OMFG
-- Seriously though, document this. It's important.
showbPrecDecs :: PragmaOptions -> [Con] -> [Q Dec]
#if __GLASGOW_HASKELL__ >= 702
showbPrecDecs opts cons =
#else
showbPrecDecs _    cons =
#endif
    [ funD 'showbPrec [ clause []
                               (normalB $ consToShow cons)
                               []
                      ]
    ] ++ inlineShowbPrecDec
      ++ inlineShowbDec
      ++ inlineShowbListDec
      ++ specializeDecs
  where
    inlineShowbPrecDec, inlineShowbDec, inlineShowbListDec :: [Q Dec]
#if __GLASGOW_HASKELL__ >= 702
    inlineShowbPrecDec = inline inlineShowbPrec 'showbPrec
    inlineShowbDec     = inline inlineShowb 'showb
    inlineShowbListDec = inline inlineShowbList 'showbList
#else
    inlineShowbPrecDec = []
    inlineShowbDec     = []
    inlineShowbListDec = []
#endif
          
#if __GLASGOW_HASKELL__ >= 702
    inline :: (PragmaOptions -> Bool) -> Name -> [Q Dec]
    inline isInlining funName
        | isInlining opts = [ pragInlD funName
# if MIN_VERSION_template_haskell(2,8,0)
                                       Inline FunLike AllPhases
# else
                                       (inlineSpecNoPhase True False)
# endif
                            ]
        | otherwise       = []
#endif
          
    specializeDecs :: [Q Dec]
#if MIN_VERSION_template_haskell(2,8,0)
    specializeDecs = (map . fmap) (PragmaD
                                       . SpecialiseInstP
                                       . AppT (ConT ''T.Show)
                                  )
                                  (specializeTypes opts)
#else
    -- There doesn't appear to be an equivalent of SpecialiseInstP in early
    -- versions Template Haskell.
    specializeDecs = []
#endif