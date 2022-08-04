{-# Language DataKinds #-}
{-# Language QuasiQuotes #-}

{- |
Module: EVM.Dev
Description: Helpers for repl driven hevm hacking
-}
module EVM.Dev where

import Data.ByteString hiding (putStrLn)
import Control.Monad.State.Strict hiding (state)
import Data.Maybe (fromJust)

import Debug.Trace

import Data.String.Here
import Control.Lens

import EVM
import EVM.SMT (withSolvers, Solver(..), formatSMT2)
import EVM.Types
import EVM.SymExec
import EVM.Solidity
import EVM.Format (formatExpr)
import qualified EVM.Fetch as Fetch
import qualified Data.Text as T
import qualified EVM.FeeSchedule as FeeSchedule

doTest :: IO ()
doTest = do
  c <- testContract
  e <- simplify <$> buildExpr c
  Prelude.putStrLn (formatExpr e)

reachable' :: IO ()
reachable' = do
  c <- testContract
  full <- simplify <$> buildExpr c
  withSolvers Z3 4 $ \solvers -> do
    (_, less) <- reachable solvers full
    putStrLn "FULL AST\n\n"
    putStrLn $ formatExpr full
    putStrLn "\n\nReachable AST\n\n"
    putStrLn $ formatExpr less

testContract :: IO ByteString
testContract = do
  let src =
        [i|
          contract C {
            uint x;
            function set(uint v) public {
              x = v;
            }
          }
          |]
  fmap fromJust (solcRuntime "C" src)

initVm :: ByteString -> VM
initVm bs = vm
  where
    contractCode = RuntimeCode $ fmap LitByte (unpack bs)
    c = Contract
      { _contractcode = contractCode
      , _balance      = 0
      , _nonce        = 0
      , _codehash     = keccak (ConcreteBuf bs)
      , _opIxMap      = mkOpIxMap contractCode
      , _codeOps      = mkCodeOps contractCode
      , _external     = False
      }
    vm = makeVm $ VMOpts
      { EVM.vmoptContract      = c
      , EVM.vmoptCalldata      = AbstractBuf "txdata"
      , EVM.vmoptValue         = CallValue 0
      , EVM.vmoptAddress       = Addr 0xffffffffffffffff
      , EVM.vmoptCaller        = Lit 0
      , EVM.vmoptOrigin        = Addr 0xffffffffffffffff
      , EVM.vmoptGas           = 0xffffffffffffffff
      , EVM.vmoptGaslimit      = 0xffffffffffffffff
      , EVM.vmoptStorageBase   = Symbolic
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


-- | Builds the Expr for the given evm bytecode object
buildExpr :: ByteString -> IO (Expr End)
buildExpr bs = evalStateT (interpret (Fetch.oracle Nothing False) Nothing Nothing runExpr) (initVm bs)
