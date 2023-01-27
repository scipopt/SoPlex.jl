# SoPlex

This is a Julia wrapper for the [SoPlex](https://soplex.zib.de/) (Sequential object-oriented simPlex) linear optimization solver
based on an implementation of the primal and dual revised simplex algorithm.

**This package is at a very early stage**, use at your own risk.
Feedback is welcome, but things are expected to break.
Contributions to fix the failing tests are welcome.

## Usage

The solver implements [MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl) and can be used directly or from JuMP.

## Installing

The package is not registered yet, install it with:

```julia
using Pkg
Pkg.add("https://github.com/scipopt/SoPlex.jl")
```
