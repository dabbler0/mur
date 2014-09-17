assert = require 'assert'

assert.equal = (a, b, m) ->
  unless a is b
    throw new Error m + ': ' + a + ' !== ' + b

assert.arrayEqual = (a, b, m) ->
  unless a.length is b.length
    throw new Error m + ': ' + a + ' !== ' + b
  for el, i in a
    unless b[i] is el
      throw new Error m + ': ' + a + ' !== ' + b
{ShadowQueue} = require './roguelike'

queue = new ShadowQueue()
queue.emplace 15, 30
queue.emplace 40, 50

assert.arrayEqual queue.queue, [15, 30, 40, 50], 'Simple emplacement'

queue.emplace 20, 45

assert.arrayEqual queue.queue, [15, 50], 'Merging'

assert.equal queue.check(30, 40), ShadowQueue.FULL, 'Checking (positive)'
assert.equal queue.check(40, 60), ShadowQueue.PARTIAL, 'Checking (partial)'
assert.equal queue.check(60, 70), ShadowQueue.NONE, 'Checking (none)'
