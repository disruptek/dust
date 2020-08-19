# dust

Given a test program that produces a semantic error, mutate the AST of that
program to remove syntax that is irrelevant to the error.

## Usage

It _will_ overwrite your source file during operation.

```
dust test.nim
```

## License
MIT
