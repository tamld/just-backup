# CMD Compiler Traps: Redirection Inside Blocks

## Context & Problem
In Windows Batch (`.bat`), the parser handles parenthesis blocks `( )` by reading the entire block into memory before executing it. When redirection symbols like `>`, `>>`, or `<` are used inside a block, the parser evaluates them prematurely.
This causes commands to fail or redirect output to bizarrely named ghost files (like `]`).

```batch
REM Anti-pattern (Causes Ghost Files):
if "%VAR%"=="1" (
    echo Log entry >> mylog.txt
)
```

## The Standardized Solution (Knowledge)
To prevent premature parsing of redirection symbols inside any bracketed block (`if`, `for`), the symbols MUST be escaped using the caret `^` character.

### Code Pattern
```batch
REM Correct Pattern: Escape the >> as ^>^>
if "%VAR%"=="1" (
    echo Log entry ^>^> mylog.txt
)
```

## Verification Checklist
1. Review all `if` and `for` blocks in batch scripts.
2. Ensure ANY use of `>`, `>>`, `|`, `<`, or `&` inside those blocks has a leading caret `^`.
3. Test the block logic execution to ensure no ghost files are created in the working directory.
