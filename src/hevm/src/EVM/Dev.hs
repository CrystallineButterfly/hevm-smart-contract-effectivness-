{-# Language DataKinds #-}

{- |
Module: EVM.Dev
Description: Helpers for repl driven hevm hacking
-}
module EVM.Dev where

import EVM
import EVM.Types
import EVM.SymExec
import qualified EVM.Fetch as Fetch
import qualified EVM.FeeSchedule as FeeSchedule

import Data.ByteString
import Control.Monad.State.Strict hiding (state)

-- | Builds the Expr for the given evm bytecode object
buildExpr :: ByteString -> IO (Expr End)
buildExpr bs = evalStateT (interpret (Fetch.oracle Nothing False) Nothing Nothing runExpr) vm
  where
    contractCode = RuntimeCode $ fmap LitByte (unpack (hexByteString "" bs))
    c = Contract
      { _contractcode = contractCode
      , _storage      = EmptyStore
      , _balance      = 0
      , _nonce        = 0
      , _codehash     = keccak (ConcreteBuf bs)
      , _opIxMap      = mkOpIxMap contractCode
      , _codeOps      = mkCodeOps contractCode
      , _external     = False
      , _origStorage  = mempty
      }
    vm = makeVm $ VMOpts
      { EVM.vmoptContract      = c
      , EVM.vmoptCalldata      = AbstractBuf
      , EVM.vmoptValue         = Lit 0
      , EVM.vmoptAddress       = Addr 0xffffffffffffffff
      , EVM.vmoptCaller        = Lit 0
      , EVM.vmoptOrigin        = Addr 0xffffffffffffffff
      , EVM.vmoptGas           = 0xffffffffffffffff
      , EVM.vmoptGaslimit      = 0xffffffffffffffff
      , EVM.vmoptBaseFee       = 0
      , EVM.vmoptPriorityFee   = 0
      , EVM.vmoptCoinbase      = 0
      , EVM.vmoptNumber        = 0
      , EVM.vmoptTimestamp     = Var "timestamp"
      , EVM.vmoptBlockGaslimit = 0
      , EVM.vmoptGasprice      = 0
      , EVM.vmoptMaxCodeSize   = 0xffffffff
      , EVM.vmoptDifficulty    = 0
      , EVM.vmoptSchedule      = FeeSchedule.berlin
      , EVM.vmoptChainId       = 1
      , EVM.vmoptCreate        = False
      , EVM.vmoptTxAccessList  = mempty
      , EVM.vmoptAllowFFI      = False
      }

