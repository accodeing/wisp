import times

template kb*(value: untyped): untyped = value * 1024
template mb*(value: untyped): untyped = value * 1024 * 1024
template gb*(value: untyped): untyped = value * 1024 * 1024 * 1024

template with_timing*(resultVar: untyped, body: untyped ): untyped =
  var resultVar: float 
  let startTime = getTime()
  body
  let endTime = getTime()
  resultVar = (endTime - startTime).inNanoseconds / 1_000_000

