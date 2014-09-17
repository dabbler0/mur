class IdObject
  constructor: ->
    @id = IdObject.last_obj_id++

  toString: -> "[IdObject #{@id}]"

IdObject.last_obj_id = 0

# SHADOWCASTING
# =============

# ShadowQueue, implemented from ondras's description
# of precise shadowcasting.
exports.ShadowQueue = class ShadowQueue
  constructor: ->
    @queue = []

  emplace: (startAngle, endAngle) ->
    startAngle %%= 360; endAngle %%= 360

    start = 0
    start++ until @queue[start] >= startAngle or start >= @queue.length

    end = @queue.length
    end-- until @queue[end] <= endAngle or end < 0

    remove = end - start + 1

    if remove %% 2 is 1
      if start %% 2 is 1
        @queue.splice start, remove, endAngle
      else
        @queue.splice start, remove, startAngle
    else
      if start %% 2 is 1
        @queue.splice start, remove
      else
        @queue.splice start, remove, startAngle, endAngle

  check: (startAngle, endAngle) ->
    startAngle %%= 360; endAngle %%= 360

    start = 0
    start++ until @queue[start] >= startAngle or start >= @queue.length

    if @queue[start] < endAngle
      return ShadowQueue.PARTIAL
    else
      if start %% 2 is 1
        return ShadowQueue.FULL
      else
        return ShadowQueue.NONE

ShadowQueue.PARTIAL = 'PARTIAL'
ShadowQueue.FULL = 'FULL'
ShadowQueue.NONE = 'NONE'

class Board extends IdObject
  constructor: (@dimensions) ->
    super
    @cells = ((new FloorCell([i, j], @) for j in [0...@dimensions.height]) for i in [0...@dimensions.width])

  getCircle: (x, y, r) ->
    coords = []
    for i in [0...r * 2]
      coords.push [x - r, y + r - i]
    for i in [0...r * 2]
      coords.push [x - r + i, y - r]
    for i in [0...r * 2]
      coords.push [x + r, y - r + i]
    for i in [0...r * 2]
      coords.push [x + r - i, y + r]

    return coords

  shadowcast: (coords, see, max = 10) ->
    visible = {}
    queue = new ShadowQueue()
    r = 0

    visible[@cells[coords[0]][coords[1]].id] = true

    until r is max
      r++
      circle = @getCircle coords[0], coords[1], r
      for [x, y], i in circle when 0 <= x < @dimensions.width and 0 <= y < @dimensions.height
        start = 360 * (2 * i - 1 %% (2 * circle.length)) / (2 * circle.length)
        end = 360 * (2 * i + 1 %% (2 * circle.length)) / (2 * circle.length)

        if queue.check(start, end) in [ShadowQueue.PARTIAL, ShadowQueue.NONE]
          visible[@cells[x][y].id] = true
        unless see @cells[x][y]
          queue.emplace start, end

    return visible

  drawCells: (visible) ->
    strs = ('' for [0...@dimensions.height])
    for col, x in @cells
      for cell, y in col
        if cell.id of visible
          strs[y] += cell.charRepr()
        else
          strs[y] += ' '

    return strs.join '\n'

class FloorCell extends IdObject
  constructor: (@board, @coord, @terrain=FloorCell.GROUND, @items=[]) ->
    super
    @blocked = false

  charRepr: ->
    switch
      when @player then '@'
      when @blocked then '0'
      else '.'

FloorCell.GROUND = 'GROUND'

# TESTS
# =====

telnet = require 'telnet'

board = new Board {width: 50, height: 50}

for col, x in board.cells
  for cell, y in col
    if Math.random() < 0.01
      cell.blocked = true
    else
      cell.blocked = false

redraws = []

server = telnet.createServer (client) ->
  client.do.transmit_binary()
  px = py = 25
  redraws.push ->
    string = board.drawCells board.shadowcast [px, py], ((cell) -> not cell.blocked), 50
    client.write '\x1B[2J\n' + string
  redraw()
  client.on 'data', (ch) ->
    ch = ch.toString()
    if ch in 'hjkluybnq'
      board.cells[px][py].player = false
      switch ch
        when 'h' then px--
        when 'j' then py++
        when 'k' then py--
        when 'l' then px++
        when 'u' then px++; py--
        when 'y' then px--; py--
        when 'b' then px--; py++
        when 'n' then px++; py++
        when 'q' then process.exit 0
      board.cells[px][py].player = true

      redraw()

server.listen 23

redraw = ->
  redrawer() for redrawer in redraws
