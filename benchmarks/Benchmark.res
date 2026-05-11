open DSL

@val external nowMs: unit => float = "Date.now"

let bench = (name: string, iterations: int, run: unit => unit) => {
  let t0 = nowMs()
  for _i in 1 to iterations {
    run()
  }
  let t1 = nowMs()
  let total = t1 -. t0
  let avg = total /. Int.toFloat(iterations)
  Console.log(
    name ++
    " | iterations=" ++
    Int.toString(iterations) ++ " | totalMs=" ++ Float.toString(total) ++ " | avgMs=" ++ Float.toString(avg),
  )
}

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

let loopDb = list{
  rule(
    compound(#loop, list{var(#X)}),
    list{compound(#loop, list{var(#X)})},
  ),
}

let runComplexQuery = () => {
  ignore(query(graphDb, compound(#path, list{atom(#a), var(#Y)}), #Y))
}

let runGuardedLoop = () =>
  try {
    ignore(solveN(loopDb, compound(#loop, list{atom(#a)}), 1))
  } catch {
  | Solver.StackOverflowGuardExceeded(_) => ()
  | _ => ()
  }

Console.log("res-prolog benchmark")
bench("complex recursive query", 2000, runComplexQuery)
bench("stack overflow guard (deep loop)", 5, runGuardedLoop)
