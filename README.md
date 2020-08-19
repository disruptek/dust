# dust

Given a test program that produces a semantic error, mutate the AST of that
program to remove syntax that is irrelevant to the error.

## Usage

It _will_ overwrite your source file during operation.

**--define:release is _strongly recommended_.**

```
dust test.nim
```

## Example

```nim
import macros

macro foo(n: typed) =
  copyNimTree(n)


# Why is this ok
foo:
  var a = 3

foo:
  let b = 3

# But this is not
foo:
  var x = 2 + 3
  if false:
    x = x + 5
  proc c() =
    echo x
    discard
```
...turns into...

```nim
import
  macros

macro foo(n: typed) =
  copyNimTree(n)

foo:
  proc c() =
    discard
```

## License
MIT
