// Browser entry point. Imports the compiled ReScript example, captures its
// console output, and renders it into the page.
const buf = []
const orig = console.log
console.log = (...args) => {
  buf.push(args.join(' '))
  orig.apply(console, args)
}

await import('../lib/es6/examples/Family.res.mjs')

document.getElementById('out').textContent = buf.join('\n')
