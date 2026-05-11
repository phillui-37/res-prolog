# res-prolog

A Prolog-inspired logical-programming framework in **ReScript 12**, modelled
after [phillui-37/fs-logical](https://github.com/phillui-37/fs-logical) but
with one key constraint:

> **No string interpolation. The type system drives everything.**

Predicate names, atom names and variable names are all **polymorphic
variants** (`#parent`, `#tom`, `#X`, …) — they exist as types, not as
strings to be parsed or concatenated. Typos become compile-time errors.

## Toolchain

* **ReScript 12** — compiles `.res` to `.res.mjs` (ESM)
* **pnpm** — package manager
* **Vite 8** — dev server / production bundle for the in-browser demo

## Features

| Concept           | Implementation                                                 |
| ----------------- | -------------------------------------------------------------- |
| Terms             | `Atom`, `Int`, `Float`, `Var`, `Compound` variant              |
| Identifiers       | Polymorphic variants — type-checked, not strings               |
| Variable hygiene  | `UserVar(name)` for user vars, `FreshVar(int)` from renaming   |
| Unification       | Robinson's algorithm with occurs check                         |
| Knowledge base    | A `database` is just a `list<clause>`                          |
| Backtracking      | Lazy `Stream.t<substitution>` — SLD resolution                 |
| Solver controls   | `solve`, `solveN`, `solveAll`, `query`, `?-`, `queryAnd`, `holds` |

## Project layout

```
src/
  Term.res          ← core types (Term, Clause, Database) + helpers
  Stream.res        ← minimal lazy stream for backtracking
  Unification.res   ← walk / resolve / occurs / unify
  Solver.res        ← variable renaming + SLD resolution
  DSL.res           ← thin re-export module for ergonomic `open`
tests/
  Tests.res         ← unit tests (run with `pnpm test`)
benchmarks/
  Benchmark.res     ← micro-benchmarks (run with `pnpm benchmark`)
examples/
  Family.res        ← parent / ancestor demo
web/
  index.html        ← Vite entry — runs the demo in the browser
  main.js           ← captures Console.log output into the page
vite.config.js      ← Vite config (root = web/)
rescript.json       ← ReScript build config
```

## Quick start

```rescript
open DSL

let family = list{
  fact(compound(#parent, list{atom(#tom), atom(#bob)})),
  fact(compound(#parent, list{atom(#tom), atom(#liz)})),
  fact(compound(#parent, list{atom(#bob), atom(#ann)})),
  fact(compound(#parent, list{atom(#bob), atom(#pat)})),

  // ancestor(X, Y) :- parent(X, Y).
  rule(
    compound(#ancestor, list{var(#X), var(#Y)}),
    list{compound(#parent, list{var(#X), var(#Y)})},
  ),
  // ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).
  rule(
    compound(#ancestor, list{var(#X), var(#Y)}),
    list{
      compound(#parent, list{var(#X), var(#Z)}),
      compound(#ancestor, list{var(#Z), var(#Y)}),
    },
  ),
}

// Who are tom's children?
let children = query(family, compound(#parent, list{atom(#tom), var(#C)}), #C)
// → list{Atom(#bob), Atom(#liz)}

// All ancestors of ann:
let ancestors = query(family, compound(#ancestor, list{var(#A), atom(#ann)}), #A)
// → list{Atom(#bob), Atom(#tom)}
```

## Why polymorphic variants?

In a string-based design you'd write things like `Var "X"` or
`"parent" /@ [...]`. A misspelling such as `Var "x"` or `"parnet"` would
silently produce a different (unbound) symbol — a class of bug that's
hard to catch.

With polymorphic variants:

* `#X`, `#parent` are inferred into a structural union type;
* if you optionally annotate the union, ReScript will reject any
  identifier outside the set you declared;
* there is no parsing, no interpolation, no template strings anywhere
  in the framework.

If you want extra safety, declare your own union and annotate the
database:

```rescript
type name = [#parent | #ancestor | #tom | #bob | #liz | #ann | #pat]
type vname = [#X | #Y | #Z | #C | #A]
let family: database<name, vname> = list{ /* ... */ }
```

Now `compound(#parnet, ...)` won't compile.

## API at a glance

```rescript
// Constructors
atom: 'name => term<'name, 'v>
int: int => term<_, _>
float_: float => term<_, _>
var: 'v => term<'name, 'v>
compound: ('name, list<term<'name, 'v>>) => term<'name, 'v>

fact: term<'n, 'v> => clause<'n, 'v>
rule: (term<'n, 'v>, list<term<'n, 'v>>) => clause<'n, 'v>

// Unification
unify: (substitution, term, term) => option<substitution>
valueOf: (substitution, 'v) => option<term>
resolve: (substitution, term) => term

// Solver
solve:    (database, term) => Stream.t<substitution>   // lazy
solveN:   (database, term, int) => list<substitution>
solveAll: (database, term) => list<substitution>
query:    (database, term, 'v) => list<term>           // values of 'v

// Prolog-style `?-` query operator (conjunction of goals)
\"?-":     (database, list<term>) => Stream.t<substitution>
queryAnd: (database, list<term>, 'v) => list<term>     // values of 'v across the conjunction
holds:    (database, list<term>) => bool               // does the conjunction succeed?
```

## The `?-` query operator

Prolog's top-level uses `?-` to introduce a query — a conjunction of
goals separated by commas. `res-prolog` mirrors this with an explicit
`\"?-"` function (and two convenience helpers) so the same three
patterns from Prolog map directly:

```prolog
?- a(X), b(X).      % find X such that both a(X) and b(X) hold
?- a(test, X).      % for relation a, what X does `test` relate to?
?- a(b).            % is b in relation a? (boolean check)
```

In ReScript the conjunction is just a `list` of goals:

```rescript
open DSL

// Pattern 1: find X satisfying both `likes(X)` and `tall(X)`.
let xs = queryAnd(
  db,
  list{compound(#likes, list{var(#X)}), compound(#tall, list{var(#X)})},
  #X,
)

// Pattern 2: what X does `tom` relate to via `parent`?
let children = queryAnd(
  db,
  list{compound(#parent, list{atom(#tom), var(#X)})},
  #X,
)

// Pattern 3: does food(burger) hold?
let yes = holds(db, list{compound(#food, list{atom(#burger)})})

// Or use the raw `?-` operator to get the lazy stream of substitutions
// (useful when you need to inspect more than one variable at a time):
let stream = \"?-"(db, list{compound(#likes, list{var(#X)}), compound(#tall, list{var(#X)})})
```

The single-goal `query` / `solve` API is unchanged; `\"?-"` is the
generalisation to a conjunction of goals.

## Build / test / run

```sh
pnpm install         # installs ReScript 12, Vite, runtime
pnpm res:build       # compile .res → lib/es6/**/*.res.mjs
pnpm test            # build + run unit tests under Node
pnpm benchmark       # build + run benchmark cases under Node
pnpm example         # build + run the family / ancestor demo
pnpm dev             # build + start Vite dev server (in-browser demo)
pnpm build           # build + Vite production bundle into dist/
```

## Benchmark cases

The benchmark entrypoint currently includes:

* a complex recursive `path/2` query workload;
* a deep self-recursive `loop/1` workload that exercises the solver's
  stack-overflow guard.
