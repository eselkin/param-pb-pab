{-# LANGUAGE DataKinds                     #-}
{-# LANGUAGE DeriveAnyClass                #-}
{-# LANGUAGE DeriveGeneric                 #-}
{-# LANGUAGE FlexibleContexts              #-}
{-# LANGUAGE GeneralizedNewtypeDeriving    #-}
{-# LANGUAGE MultiParamTypeClasses         #-}
{-# LANGUAGE NoImplicitPrelude             #-}
{-# LANGUAGE OverloadedStrings             #-}
{-# LANGUAGE ScopedTypeVariables           #-}
{-# LANGUAGE TemplateHaskell               #-}
{-# LANGUAGE TypeApplications              #-}
{-# LANGUAGE TypeFamilies                  #-}
{-# LANGUAGE TypeOperators                 #-}
{-# OPTIONS_GHC -fno-warn-unused-imports   #-}
{-# OPTIONS_GHC -fno-warn-unused-top-binds #-}

module Plutus.Contracts.ParameterisedPiggyBank where

import           Control.Lens         (view)
import           Control.Monad        hiding (fmap)
import           Data.Aeson           (ToJSON, FromJSON)
import           Data.Map             as Map hiding (empty)
import           Data.Text            (Text, unpack, pack)
import           Data.Monoid          (Last (..))
import           Data.Void            (Void)
import           GHC.Generics         (Generic)
import           Plutus.Contract.Types
import           PlutusTx             (toBuiltinData)
import qualified PlutusTx
import           PlutusTx.Prelude     hiding (Semigroup(..), unless)
import qualified PlutusTx.Prelude     as Plutus
import           Ledger               hiding (singleton)
import           Ledger.Constraints   as Constraints
import qualified Ledger.Typed.Scripts as Scripts
import           Ledger.Ada           as Ada
import           Playground.Contract  (printJson, printSchemas, ensureKnownCurrencies, stage, ToSchema)
import           Playground.TH        (mkKnownCurrencies, mkSchemaDefinitions)
import           Playground.Types     (KnownCurrency (..))
import           Prelude              (IO, Semigroup (..), String, Show (..))
import           Text.Printf          (printf)
import           Data.Text.Prettyprint.Doc.Extras (PrettyShow (..))
import           Plutus.Contract       as Contract
import           Plutus.V1.Ledger.Value (Value (..), assetClass, assetClassValueOf)
import qualified Data.Map             as Map

-- A value which initates 
data PutParams = PutParams
    { ppBeneficiary :: !PubKeyHash
    , ppAmount      :: !Integer
    } deriving (Generic, ToJSON, FromJSON, ToSchema, Show)

-- A beneficiary gets their own script address
newtype BankParam = BankParam
    { beneficiary :: PubKeyHash
    } deriving Show

-- Endpoints of schema
type ParameterisedPiggyBankSchema =
            Endpoint "put" PutParams
        .\/ Endpoint "empty" ()
        .\/ Endpoint "inspect" PubKeyHash

{- 
    Typed validator instance (probably should be PiggyTyped)
    There's no Datum even though you might think there is one from PutParams
-}
data Bank
instance Scripts.ValidatorTypes Bank where
    type instance DatumType Bank    = ()
    type instance RedeemerType Bank = ()

PlutusTx.makeLift ''BankParam

{- 
    here p is to get validate the scriptAddress needs the beneficiary to have signed the current context 
    Remember, no datum or redeemer (since it's checking the person's own signature)
-}
{-# INLINABLE mkValidator #-}
mkValidator :: BankParam -> () -> () -> ScriptContext -> Bool
mkValidator bp () () ctx =
    hasSufficientAmount &&
    signedByBeneficiary

    where
      contextTxInfo :: TxInfo
      contextTxInfo = scriptContextTxInfo ctx

      hasSufficientAmount :: Bool
      hasSufficientAmount =
          traceIfFalse "Sorry. Not enough lovelace" $ checkAmount $ inValue contextTxInfo

      signedByBeneficiary :: Bool
      signedByBeneficiary = txSignedBy contextTxInfo $ beneficiary bp

{-# INLINABLE inValue #-}
inValue :: TxInfo -> Value
inValue = valueSpent

{-# INLINABLE checkAmount #-}
checkAmount :: Value -> Bool
checkAmount val = assetClassValueOf val (assetClass Ada.adaSymbol Ada.adaToken) > 1000000


typedValidator :: BankParam -> Scripts.TypedValidator Bank
typedValidator p = Scripts.mkTypedValidator @Bank
    ($$(PlutusTx.compile [|| mkValidator ||]) `PlutusTx.applyCode` PlutusTx.liftCode p)
    $$(PlutusTx.compile [|| wrap ||])
    where
        wrap = Scripts.wrapValidator @() @()


validator :: BankParam -> Validator
validator = Scripts.validatorScript . typedValidator

valHash :: BankParam ->  Ledger.ValidatorHash
valHash = Scripts.validatorHash . typedValidator

{-
    scrAddress needs the BankParam (for the beneficiary!)
-}
scrAddress :: BankParam ->  Ledger.Address
scrAddress = scriptAddress . validator

put :: PutParams -> Contract w s Text ()
put pp =  do
    let bp  = BankParam
                    { beneficiary = ppBeneficiary pp
                    }
        tx = mustPayToTheScript () $ Ada.lovelaceValueOf (ppAmount pp)
    ledgerTx <- submitTxConstraints (typedValidator bp) tx
    void $ awaitTxConfirmed $ txId ledgerTx
    logInfo  @String $ "Added " ++ show (ppAmount pp) ++ " to scrAddress for " ++ show (ppBeneficiary pp)

inspect :: forall w s . PubKeyHash -> Contract w s Text ()
inspect pkh = do
    let bp = BankParam { beneficiary = pkh}
    os  <- PlutusTx.Prelude.map snd . Map.toList <$> utxosAt (scrAddress bp)
    let totalVal = mconcat [view ciTxOutValue o | o <- os]
    logInfo @String
        $ "Logging total Value : " <> show totalVal
    logInfo @String $ "Inspect complete"

empty :: forall w s . () -> Contract w s Text ()
empty _ = do
    pkh <- pubKeyHash <$> ownPubKey
    let bp  = BankParam
                        { beneficiary = pkh
                        }
    utxos <- utxosAt $ scrAddress bp
    let orefs   = fst <$> Map.toList utxos
        lookups = Constraints.unspentOutputs utxos <>
                  Constraints.otherScript (validator bp)
        tx :: TxConstraints Void Void
        tx      = mconcat [mustSpendScriptOutput oref $ Redeemer $ toBuiltinData () | oref <- orefs]
    ledgerTx <- submitTxConstraintsWith @Void lookups tx
    awaitTxConfirmed $ txId ledgerTx
    logInfo @String $ "Emptied piggy bank."



endpoints :: Contract () ParameterisedPiggyBankSchema Text e
endpoints = do
    logInfo @String "Waiting for empty or put or inspect."
    selectList [give', grab', inspect'] >> endpoints
      where
        give' = endpoint @"put" put
        grab' = endpoint @"empty" empty
        inspect' = endpoint @"inspect" inspect

mkSchemaDefinitions ''ParameterisedPiggyBankSchema

$(mkKnownCurrencies [])
