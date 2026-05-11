/***
  SLD resolution with lazy backtracking.

  For each goal, we try every clause in the database in order:
    1. Rename the clause's variables to fresh ids (so user variables in
       different invocations don't collide).
    2. Unify the goal with the (renamed) clause head.
    3. On success, prepend the (renamed) clause body to the remaining
       goals and recurse.

  Results are produced as a lazy `Stream.t<substitution>` so callers can
  ask for just `solveN(db, goal, 1)` without materialising every answer.
*/

open Term
open Unification

exception StackOverflowGuardExceeded(int)

/* Keep this conservative so the guard triggers before JS engine stack overflow. */
let stackOverflowGuardLimit = 1000

/* --- Renaming --- */

let renameTerm = (mapping: list<(varId<'v>, varId<'v>)>, t: term<'n, 'v>): term<'n, 'v> => {
  let rec lookupV = (m, v) =>
    switch m {
    | list{} => None
    | list{(a, b), ...rest} => v == a ? Some(b) : lookupV(rest, v)
    }
  let rec go = t =>
    switch t {
    | Var(v) =>
      switch lookupV(mapping, v) {
      | Some(v') => Var(v')
      | None => Var(v)
      }
    | Compound(name, args) => Compound(name, args->List.map(go))
    | _ => t
    }
  go(t)
}

let renameClause = (counter: ref<int>, c: clause<'n, 'v>): clause<'n, 'v> => {
  let vars = clauseVars(c)
  let mapping = vars->List.map(v => {
    let i = counter.contents
    counter := i + 1
    (v, FreshVar(i))
  })
  {
    head: renameTerm(mapping, c.head),
    body: c.body->List.map(renameTerm(mapping, _)),
  }
}

/* --- Solver --- */

/* Solve a list of goals against a database, starting from substitution `s`.
   Returns a lazy stream of substitutions, each representing one successful
   resolution path. */
let rec solveGoals = (
  db: database<'n, 'v>,
  counter: ref<int>,
  steps: ref<int>,
  goals: list<term<'n, 'v>>,
  s: substitution<'n, 'v>,
): Stream.t<substitution<'n, 'v>> =>
  switch goals {
  | list{} => Stream.single(s)
  | list{g, ...rest} =>
    let goal = walk(s, g)
    let tryClause = (clause: clause<'n, 'v>): Stream.t<substitution<'n, 'v>> => {
      steps := steps.contents + 1
      if steps.contents > stackOverflowGuardLimit {
        throw(StackOverflowGuardExceeded(steps.contents))
      }
      let renamed = renameClause(counter, clause)
      switch unify(s, goal, renamed.head) {
      | None => Stream.nil
      | Some(s') =>
        () => solveGoals(db, counter, steps, List.concat(renamed.body, rest), s')()
      }
    }
    Stream.flatMap(Stream.ofList(db), tryClause)
  }

let solve = (db: database<'n, 'v>, goal: term<'n, 'v>): Stream.t<substitution<'n, 'v>> => {
  let counter = ref(0)
  let steps = ref(0)
  solveGoals(db, counter, steps, list{goal}, empty)
}

let solveN = (db, goal, n) => Stream.take(solve(db, goal), n)
let solveAll = (db, goal) => Stream.toList(solve(db, goal))

/* Convenience: run a query and project the value of one user variable. */
let query = (db: database<'n, 'v>, goal: term<'n, 'v>, v: 'v): list<term<'n, 'v>> =>
  solveAll(db, goal)
  ->List.filterMap(s => Unification.valueOf(s, v))

/* --- Prolog-style `?-` query operator ---

   Mirrors Prolog's top-level query syntax, where a query is a conjunction
   of goals separated by commas:

       ?- a(X), b(X).      // find X such that both a(X) and b(X) hold
       ?- a(test, X).      // for relation a, what X does `test` relate to?
       ?- a(b).            // does a(b) hold?

   In ReScript the conjunction is expressed as a `list<term<...>>`.
   `\"?-"` returns the lazy stream of substitutions, exactly like `solve`,
   but generalised over a goal list.

   Companion helpers:
     - `queryAnd` projects the value of one user variable across the
       conjunction (handles patterns 1 and 2);
     - `holds` answers the boolean question (pattern 3). */
let \"?-" = (
  db: database<'n, 'v>,
  goals: list<term<'n, 'v>>,
): Stream.t<substitution<'n, 'v>> => {
  let counter = ref(0)
  let steps = ref(0)
  solveGoals(db, counter, steps, goals, empty)
}

let queryAnd = (
  db: database<'n, 'v>,
  goals: list<term<'n, 'v>>,
  v: 'v,
): list<term<'n, 'v>> =>
  Stream.toList(\"?-"(db, goals))
  ->List.filterMap(s => Unification.valueOf(s, v))

let holds = (db: database<'n, 'v>, goals: list<term<'n, 'v>>): bool =>
  switch \"?-"(db, goals)() {
  | Stream.Nil => false
  | Stream.Cons(_, _) => true
  }
