{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE DerivingVia                #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TypeApplications           #-}
{-# LANGUAGE TypeOperators              #-}
{-# LANGUAGE UndecidableInstances       #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

module Control.Carrier.Sketch.Fresh
  ( SketchC (..)
  , runSketch
  , module Control.Effect.Sketch
  ) where

import           Control.Algebra
import           Control.Carrier.Fresh.Strict
import           Control.Carrier.State.Strict
import           Control.Effect.Sketch
import           Control.Monad.IO.Class
import           Data.Bifunctor
import           Data.Maybe
import           Data.Monoid
import           Data.Monoid.Generic
import           Data.ScopeGraph (ScopeGraph)
import qualified Data.ScopeGraph as ScopeGraph
import           Data.Semilattice.Lower
import           GHC.Generics (Generic)
import qualified System.Path as Path

newtype Sketchbook address = Sketchbook
  { sGraph  :: ScopeGraph address
  } deriving (Eq, Show, Lower)

newtype SketchC address m a = SketchC (StateC (Sketchbook address) (FreshC m) a)
  deriving (Applicative, Functor, Monad, MonadIO)

instance forall address sig m . (Effect sig, Algebra sig m) => Algebra (Sketch address :+: sig) (SketchC address m) where
  alg (L (Declare name _props k)) = do
    ua <- SketchC fresh
    ub <- SketchC fresh
    parent <- SketchC (gets @(Sketchbook address) getParent)

    let newScope = ScopeGraph.scope ua
    let newDecl  = ScopeGraph.decl ub name
    let newGraph = ScopeGraph.edge parent newScope
                   <> ScopeGraph.edge newScope newDecl

    SketchC (modify ())

    k ()
  alg (R other) = SketchC (alg (R (R (handleCoercible other))))

runSketch ::
  (ScopeGraph.Addressable address, Functor m)
  => Maybe Path.AbsRelFile
  -> SketchC address m a
  -> m (ScopeGraph address, a)
runSketch rootpath (SketchC go)
  = evalFresh 0
  . fmap (first sGraph)
  . runState lowerBound
  $ go

