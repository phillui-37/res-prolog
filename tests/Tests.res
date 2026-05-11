/***
  Tests for the logical framework. We use plain assertions (no test
  framework) so the suite can run via `node` without extra deps.
*/

open DSL

let failures = ref(0)
let total = ref(0)

let check = (name, cond) => {
  total := total.contents + 1
  if !cond {
    failures := failures.contents + 1
    Console.log("FAIL: " ++ name)
  } else {
    Console.log("ok:   " ++ name)
  }
}

let checkEq = (name, actual, expected) => check(name, actual == expected)

/* ---------- Unification ---------- */

/* unify(atom(#a), atom(#a)) succeeds with empty subst. */
check(
  "atom = atom (same) succeeds",
  switch unify(list{}, atom(#a), atom(#a)) {
  | Some(_) => true
  | None => false
  },
)

check(
  "atom = atom (different) fails",
  switch unify(list{}, atom(#a), atom(#b)) {
  | None => true
  | Some(_) => false
  },
)

/* unify(var(#X), atom(#a)) binds X. */
check(
  "var binds to atom",
  switch unify(list{}, var(#X), atom(#a)) {
  | Some(s) => valueOf(s, #X) == Some(atom(#a))
  | None => false
  },
)

/* compound with vars: parent(X, b) = parent(a, Y) ⇒ X=a, Y=b */
check(
  "compound unification binds both vars",
  switch unify(
    list{},
    compound(#parent, list{var(#X), atom(#b)}),
    compound(#parent, list{atom(#a), var(#Y)}),
  ) {
  | Some(s) => valueOf(s, #X) == Some(atom(#a)) && valueOf(s, #Y) == Some(atom(#b))
  | None => false
  },
)

/* Different functor names refuse to unify. */
check(
  "different functor names fail",
  switch unify(
    list{},
    compound(#parent, list{atom(#a)}),
    compound(#child, list{atom(#a)}),
  ) {
  | None => true
  | Some(_) => false
  },
)

/* Occurs check: X = f(X) must fail. */
check(
  "occurs check rejects X = f(X)",
  switch unify(list{}, var(#X), compound(#f, list{var(#X)})) {
  | None => true
  | Some(_) => false
  },
)

/* Int / Float */
check(
  "int = int succeeds when equal",
  switch unify(list{}, int(1), int(1)) {
  | Some(_) => true
  | None => false
  },
)
check(
  "int = int fails when different",
  switch unify(list{}, int(1), int(2)) {
  | None => true
  | Some(_) => false
  },
)
check(
  "float = float succeeds when equal",
  switch unify(list{}, float_(1.5), float_(1.5)) {
  | Some(_) => true
  | None => false
  },
)
check(
  "float = float fails when different",
  switch unify(list{}, float_(1.5), float_(2.5)) {
  | None => true
  | Some(_) => false
  },
)

/* Transitive resolution: X = Y, Y = a ⇒ X resolves to a */
check(
  "transitive resolution X=Y, Y=a ⇒ X=a",
  switch unify(list{}, var(#X), var(#Y)) {
  | None => false
  | Some(s1) =>
    switch unify(s1, var(#Y), atom(#a)) {
    | None => false
    | Some(s2) => valueOf(s2, #X) == Some(atom(#a))
    }
  },
)

/* ---------- Solver: facts only ---------- */

let parents = list{
  fact(compound(#parent, list{atom(#tom), atom(#bob)})),
  fact(compound(#parent, list{atom(#tom), atom(#liz)})),
  fact(compound(#parent, list{atom(#bob), atom(#ann)})),
}

let childrenOfTom = query(parents, compound(#parent, list{atom(#tom), var(#C)}), #C)
checkEq("query children of tom (facts)", childrenOfTom, list{atom(#bob), atom(#liz)})

let parentsOfAnn = query(parents, compound(#parent, list{var(#P), atom(#ann)}), #P)
checkEq("query parents of ann", parentsOfAnn, list{atom(#bob)})

/* No solutions */
let none_ = query(parents, compound(#parent, list{atom(#nobody), var(#C)}), #C)
checkEq("query with no solutions returns empty", none_, list{})

/* Simple true/false checks: like ?- food(burger). */
let foodDb = list{
  fact(compound(#food, list{atom(#burger)})),
  fact(compound(#food, list{atom(#salad)})),
}
check(
  "food(burger) is true",
  List.length(solveAll(foodDb, compound(#food, list{atom(#burger)}))) == 1,
)
check(
  "food(pizza) is false",
  List.length(solveAll(foodDb, compound(#food, list{atom(#pizza)}))) == 0,
)

/* ---------- Solver: rules + recursion ---------- */

let withAncestor = List.concatMany([
  parents,
  list{
    fact(compound(#parent, list{atom(#ann), atom(#zoe)})),
    rule(
      compound(#ancestor, list{var(#X), var(#Y)}),
      list{compound(#parent, list{var(#X), var(#Y)})},
    ),
    rule(
      compound(#ancestor, list{var(#X), var(#Y)}),
      list{
        compound(#parent, list{var(#X), var(#Z)}),
        compound(#ancestor, list{var(#Z), var(#Y)}),
      },
    ),
  },
])

let ancestorsOfZoe = query(withAncestor, compound(#ancestor, list{var(#A), atom(#zoe)}), #A)
/* Order: rule 1 first (direct: ann), then rule 2 (transitive: bob, then tom). */
checkEq(
  "ancestors of zoe",
  ancestorsOfZoe,
  list{atom(#ann), atom(#tom), atom(#bob)},
)

let descendantsOfTom = query(withAncestor, compound(#ancestor, list{atom(#tom), var(#D)}), #D)
checkEq(
  "descendants of tom",
  descendantsOfTom,
  list{atom(#bob), atom(#liz), atom(#ann), atom(#zoe)},
)

/* ---------- Solver: complex recursive case ---------- */

let graphDb = list{
  fact(compound(#edge, list{atom(#a), atom(#b)})),
  fact(compound(#edge, list{atom(#a), atom(#d)})),
  fact(compound(#edge, list{atom(#b), atom(#c)})),
  fact(compound(#edge, list{atom(#c), atom(#d)})),
  rule(
    compound(#path, list{var(#X), var(#Y)}),
    list{compound(#edge, list{var(#X), var(#Y)})},
  ),
  rule(
    compound(#path, list{var(#X), var(#Y)}),
    list{
      compound(#edge, list{var(#X), var(#Z)}),
      compound(#path, list{var(#Z), var(#Y)}),
    },
  ),
}

let reachableFromA = query(graphDb, compound(#path, list{atom(#a), var(#Y)}), #Y)
/* Duplicate #d is intentional: two proof paths (direct edge and via b->c->d). */
checkEq(
  "complex recursive path query from a",
  reachableFromA,
  list{atom(#b), atom(#d), atom(#c), atom(#d)},
)

/* ---------- Stream laziness: solveN ---------- */

/* Build a database of nat/1 facts so we can ensure solveN doesn't enumerate all. */
let nats = list{
  fact(compound(#nat, list{int(0)})),
  fact(compound(#nat, list{int(1)})),
  fact(compound(#nat, list{int(2)})),
  fact(compound(#nat, list{int(3)})),
  fact(compound(#nat, list{int(4)})),
}
let firstTwo = solveN(nats, compound(#nat, list{var(#N)}), 2)
checkEq("solveN returns the first N answers", List.length(firstTwo), 2)

/* ---------- Renaming: variables in rules don't clash across calls ---------- */

/* eq(X, X). Asking eq(a, b) must fail; eq(a, a) must succeed. */
let eqDb = list{fact(compound(#eq, list{var(#X), var(#X)}))}
check(
  "eq(a, a) succeeds",
  List.length(solveAll(eqDb, compound(#eq, list{atom(#a), atom(#a)}))) == 1,
)
check(
  "eq(a, b) fails",
  List.length(solveAll(eqDb, compound(#eq, list{atom(#a), atom(#b)}))) == 0,
)

/* ---------- Stack overflow guard ---------- */

let loopDb = list{
  rule(
    compound(#loop, list{var(#X)}),
    list{compound(#loop, list{var(#X)})},
  ),
}

let guardTriggered =
  try {
    ignore(solveN(loopDb, compound(#loop, list{atom(#a)}), 1))
    false
  } catch {
  | Solver.StackOverflowGuardExceeded(_) => true
  | _ => false
  }

check("stack overflow guard triggers on deep recursion", guardTriggered)

/* ---------- Summary ---------- */

Console.log("")
Console.log(
  "Tests: " ++ Int.toString(total.contents - failures.contents) ++ "/" ++ Int.toString(total.contents) ++ " passed",
)
if failures.contents > 0 {
  Console.log("FAILED")
  %raw(`process.exit(1)`)
} else {
  Console.log("OK")
}
