import EtnaWitnesses.Regressions.UpgradeBoundary

open Etna.Design Etna.Design.UpgradeBoundary

example (s : System) (p : Plan) : prepare none s p = s := disabled_prepare s p
example (s : System) (persisted : Bool) : activate none s persisted = s := disabled_activate s persisted
example (s : System) (authority : Option Authority) : activate authority s false = s := failed_switch_atomic authority s
example : UpgradeBoundaryRegression.successfulBoundary := UpgradeBoundaryRegression.switch_success
example : UpgradeBoundaryRegression.historicalRetry := UpgradeBoundaryRegression.cached_old_rules
example : UpgradeBoundaryRegression.priorHistory := UpgradeBoundaryRegression.prior_history_preserved
