require 'colors'

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
    startAngle %%= 360; unless endAngle is 360 then endAngle %%= 360
    if startAngle > endAngle
      @emplace 0, endAngle
      @emplace startAngle, 360
      return
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
    startAngle %%= 360; unless endAngle is 360 then endAngle %%= 360
    if startAngle > endAngle
      begin = @check 0, endAngle
      end = @check startAngle, 360
      if ShadowQueue.PARTIAL in [begin, end] or begin isnt end
        return ShadowQueue.PARTIAL
      else
        return begin
    start = 0
    start++ until @queue[start] > startAngle or start >= @queue.length

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
    @cells = ((new FloorCell(@, [i, j]) for j in [0...@dimensions.height]) for i in [0...@dimensions.width])

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

  shadowcast: (coords, see, max = 10, qp = []) ->
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

        if queue.check(start, end) is ShadowQueue.PARTIAL
          visible[@cells[x][y].id] = false
        else if queue.check(start, end) is ShadowQueue.NONE
          visible[@cells[x][y].id] = true
        unless see @cells[x][y]
          queue.emplace start, end

    qp.push queue

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
  constructor: (@board, @coord, @terrain=FloorCell.GROUND, @items={}) ->
    super

  charRepr: ->
    # Attempt to display an item
    best = null; max = -Infinity
    for key, val of @items
      if val.priority > max
        best = val; max = val.priority
    if best?
      return best.charRepr()

    # If no items, display terrain
    else
      switch @terrain
        when FloorCell.WALL then '#'.red
        else '.'

FloorCell.GROUND = 'GROUND'
FloorCell.WALL = 'WALL'

class Item extends IdObject
  constructor: (@floor) ->
    super
    @priority = 0
    if @floor instanceof FloorCell
      @floor.items[@id] = @
    else if @floor instanceof Denizen
      @floor.inventory[@id] = @

  charRepr: ->
    return '?'

class Gem extends Item
  charRepr: ->
    return '*'

class Sapphire extends Gem
  charRepr: ->
    return '*'.blue

class Denizen extends Item
  constructor: (@floor) ->
    super @floor
    @priority = 1
    @health = 100
    @inventory = {}
    @handlers = die: []
    @dead = false

  canMoveTo: (floor) -> floor.terrain is FloorCell.GROUND

  move: (vector) ->
    x = @floor.coord[0] + vector[0]
    y = @floor.coord[1] + vector[1]

    unless 0 <= x < @floor.board.dimensions.width and 0 <= y < @floor.board.dimensions.height and
        @canMoveTo @floor.board.cells[x][y]
      return false

    delete @floor.items[@id]
    @floor = @floor.board.cells[x][y]
    @floor.items[@id] = @

    return true

  damage: (amount) ->
    @health -= amount
    if @health <= 10 then @die()

  fire: (dir) ->
    x = @floor.coord[0] + dir[0]
    y = @floor.coord[1] + dir[1]

    until not @floor.board.cells[x]?[y]? or @floor.board.cells[x][y].terrain is FloorCell.WALL
      for id, item of @floor.board.cells[x][y].items
        console.log 'CHECKING', x, y, id
        if item instanceof Denizen
          console.log 'DAMAGING'
          item.damage 10
      x += dir[0]
      y += dir[1]

  on: (ev, f) ->
    @handlers[ev]?.push f

  die: ->
    @dead = true
    delete @floor.items[@id]
    for key, val of @inventory
      @floor.items[key] = val

    for handler in @handlers.die
      handler()

    return true

  charRepr: ->
    return 'X'

class Player extends Denizen
  constructor: (@floor) ->
    super @floor
    @priority = 2

  charRepr: ->
    return '@'.inverse

# TESTS
# =====

telnet = require 'telnet'

board = new Board {width: 80, height: 24}

for col, x in board.cells
  for cell, y in col
    if Math.random() < 0.1
      cell.terrain = FloorCell.WALL
    else
      cell.terrain = FloorCell.GROUND

flags = ((false for [0...board.dimensions.height]) for [0...board.dimensions.width])

for [1..200]
  for col, x in board.cells
    for cell, y in col
      aliveNeighbors = 0
      aliveNeighbors++ for neighbor in [board.cells[x + 1]?[y],
        board.cells[x]?[y + 1],
        board.cells[x + 1]?[y + 1],
        board.cells[x + 1]?[y - 1],
        board.cells[x - 1]?[y + 1],
        board.cells[x - 1]?[y - 1],
        board.cells[x - 1]?[y],
        board.cells[x]?[y - 1]] when neighbor?.terrain is FloorCell.WALL

      if aliveNeighbors in [2, 3]
        flags[x][y] = FloorCell.WALL
      else
        flags[x][y] = FloorCell.GROUND

  for col, x in flags
    for cell, y in col
      board.cells[x][y].terrain = cell

redraws = []

console.log 'created board'

movementMap = {
  'h': [-1, 0]
  'j': [0, 1]
  'k': [0, -1]
  'l': [1, 0]
  'u': [1, -1]
  'y': [-1, -1]
  'b': [-1, 1]
  'n': [1, 1]
}

server = telnet.createServer (client) ->
  console.log 'got new client'
  client.do.transmit_binary()

  # Make a new Player
  player = new Player board.cells[Math.floor Math.random() * board.dimensions.width][Math.floor Math.random() * board.dimensions.height]

  # Give them a Gem
  gem = new Sapphire player

  redraws.push handler = ->
    string = board.drawCells board.shadowcast player.floor.coord,
        ((cell) -> cell.terrain isnt FloorCell.WALL), Math.max(board.dimensions.height, board.dimensions.width), a = []
    client.write '\x1B[2J\n' + string + '\nHP\t' + player.health + '\tGems\t' + Object.keys(player.inventory).length

  redraw()
  closed = false
  client.on 'close', ->
    closed = true
    unless player.dead
      player.die()

  player.on 'die', ->
    unless closed
      client.destroy()
    redraws.splice redraws.indexOf(handler), 1

  mode = 'MOVE'

  client.on 'data', (str) ->
    for ch in str.toString()
      if ch of movementMap
        if mode is 'MOVE'
          player.move movementMap[ch]
        else if mode is 'FIRE'
          player.fire movementMap[ch]
          mode = 'MOVE'
      else if ch is 'f'
        mode = 'FIRE'
      else if ch is ','
        for id, item of player.floor.items when item isnt player
          delete player.floor.items[id]
          player.inventory[id] = item

      if ch in 'hjklyubnf,'
        redraw()

redraws.push ->
  string = board.drawCells board.shadowcast [0, 0], ((cell) -> true), Math.max(board.dimensions.height, board.dimensions.width), a = []
  console.log '\n' + string

server.listen 23

redraw = ->
  redrawer() for redrawer in redraws
