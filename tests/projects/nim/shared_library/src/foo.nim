proc fibonacci(n: int): int {.cdecl, exportc, dynlib.} =
  if n < 2:
    result = n
  else:
    result = fibonacci(n - 1) + (n - 2).fibonacci
