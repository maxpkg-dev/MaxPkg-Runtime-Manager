# Toolbar UI

The dockable toolbar implementation lives in `core/toolbar.ms` because its
rollout callbacks and toolbar controller must share one lexical scope. Keeping
them together prevents a second global object from being introduced.
