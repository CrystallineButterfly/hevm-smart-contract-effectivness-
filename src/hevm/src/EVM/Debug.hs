module EVM.Debug where

import EVM          (Contract, storage, nonce, balance, bytecode, codehash)
import EVM.Solidity (SrcMap, srcMapFile, srcMapOffset, srcMapLength, SourceCache, sourceFiles)
import EVM.Types    (Addr)
import EVM.Expr     (bufLength)

import Control.Arrow   (second)
import Control.Lens
import Data.ByteString (ByteString)
import Data.Map        (Map)
import Data.Text       (Text)

import qualified Data.ByteString       as ByteString
import qualified Data.Map              as Map

import Text.PrettyPrint.ANSI.Leijen

data Mode = Debug | Run | JsonTrace deriving (Eq, Show)

object :: [(Doc, Doc)] -> Doc
object xs =
  group $ lbrace
    <> line
    <> indent 2 (sep (punctuate (char ';') [k <+> equals <+> v | (k, v) <- xs]))
    <> line
    <> rbrace

prettyContract :: Contract -> Doc
prettyContract c =
  object
    [ (text "codesize", text . show $ (bufLength (c ^. bytecode)))
    , (text "codehash", text (show (c ^. codehash)))
    , (text "balance", int (fromIntegral (c ^. balance)))
    , (text "nonce", int (fromIntegral (c ^. nonce)))
    -- TODO: this thing here
    --, (text "storage", text (show (c ^. storage)))
    ]

prettyContracts :: Map Addr Contract -> Doc
prettyContracts x =
  object
    (map (\(a, b) -> (text (show a), prettyContract b))
     (Map.toList x))

srcMapCodePos :: SourceCache -> SrcMap -> Maybe (Text, Int)
srcMapCodePos cache sm =
  fmap (second f) $ cache ^? sourceFiles . ix (srcMapFile sm)
  where
    f v = ByteString.count 0xa (ByteString.take (srcMapOffset sm - 1) v) + 1

srcMapCode :: SourceCache -> SrcMap -> Maybe ByteString
srcMapCode cache sm =
  fmap f $ cache ^? sourceFiles . ix (srcMapFile sm)
  where
    f (_, v) = ByteString.take (min 80 (srcMapLength sm)) (ByteString.drop (srcMapOffset sm) v)
