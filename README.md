# SoPlex

This is a Julia wrapper to the SoPlex (Sequential object-oriented simPlex) linear optimization solver
based on an advanced implementation of the primal and dual revised simplex algorithm.

## Installing

The installation of the package requires an environment variable `SOPLEX_DIR` set to the root of the soplex source project
and **assumes** there is a subfolder `/build` that contains the built soplex.
The build process must be performed once only.
