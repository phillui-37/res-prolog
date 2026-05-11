/***
  Small DSL surface re-exporting the most commonly-needed helpers so user
  code can `open ResProlog.DSL` (or just `open DSL`) and stay terse.

  The whole API is type-driven:

      let db = list{
        fact(compound(#parent, list{atom(#tom), atom(#bob)})),
        fact(compound(#parent, list{atom(#tom), atom(#liz)})),
        // ancestor(X, Y) :- parent(X, Y).
        rule(
          compound(#ancestor, list{var(#X), var(#Y)}),
          list{compound(#parent, list{var(#X), var(#Y)})},
        ),
      }

  Predicate names (`#parent`, `#ancestor`), atoms (`#tom`, `#liz`) and
  variables (`#X`, `#Y`) are all polymorphic variants — typos are caught
  at compile time.
*/

include Term

let solve = Solver.solve
let solveAll = Solver.solveAll
let solveN = Solver.solveN
let query = Solver.query

/* Generic conjunction-query helpers: take a `list` of goals (the
   conjunction) instead of a single goal. See `Solver.res` for details.
     - `solveAnd` — lazy stream of substitutions
     - `queryAnd` — values of one user variable across the conjunction
     - `holds`    — boolean: does the conjunction succeed at least once? */
let solveAnd = Solver.solveAnd
let queryAnd = Solver.queryAnd
let holds = Solver.holds

let unify = Unification.unify
let valueOf = Unification.valueOf
let resolve = Unification.resolve
