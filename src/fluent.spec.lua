local pprint = require 'cc.pretty'.pretty_print

local function reportHandler ()
  local eventname = {
    ERROR = 'ERROR',
    OPENED = 'OPENED',
    CLOSED = 'CLOSED',
    NEW_TEST_GROUP_OPEN = 'NEW_TEST_GROUP_OPEN',
    NEW_TEST_GROUP_CLOSED = 'NEW_TEST_GROUP_CLOSED',
    TEST_GROUP_START = 'TEST_GROUP_START',
    TEST_GROUP_END = 'TEST_GROUP_END',
    TEST_GROUP_SKIPPED = 'SKIPPED_TEST_GROUP',
    NEW_UNIT_TEST = 'NEW_UNIT_TEST',
    UNIT_TEST_START = 'UNIT_TEST_START',
    UNIT_TEST_END = 'UNIT_TEST_END',
    UNIT_TEST_SKIPPED = 'UNIT_TEST_SKIPPED',
    TESTING_START = 'TESTING_START',
    TESTING_END = 'TESTING_END'
  };

  local failures = {}
  local successCount = 0
  local currentGroup
  local termSize = { term.getSize() }

  return function (event, details)
    if event == eventname.TEST_GROUP_START then
      currentGroup = details.title

      -- print(details.title)
    elseif event == eventname.UNIT_TEST_END then
      if term.getCursorPos() > termSize[1] - 2 then
        print()
      end

      if details.success then
        successCount = successCount + 1

        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.write('.')
      else
        details.group = currentGroup

        table.insert(failures, details)
  
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write('F')
      end
    elseif event == eventname.TEST_GROUP_END then

      term.setBackgroundColor(colors.black)
      term.setTextColor(colors.white)
      -- print()
    elseif event == eventname.TESTING_END then
      if #failures > 0 then
        print()
        print()
  
        term.setTextColor(colors.red)
        print('!! ' .. tostring(#failures) .. ' test(s) failed:')
        term.setTextColor(colors.white)

        for _, failure in ipairs(failures) do
          print()
          print(failure.group .. ': ' .. failure.title)
          pprint(failure.result[1])
        end
      else
        print()
        print()

        term.setTextColor(colors.green)
        print('** ' .. tostring(successCount) .. ' test(s) passed!')
        term.setTextColor(colors.white)
      end
    else
      return
    end
    
    -- sleep(0.01)
  end
end

local expect = require('expect').expect
local describe, it, test = require('lut').lut(reportHandler)

local fluent = require 'fluent'

describe('Fluent.constructor', function ()
  it('should create a Fluent instance', function ()
    local fl = fluent()

    expect(function ()
      return getmetatable(fl).__index
    end):toEqual(fluent)
  end)

  it('should create a Fluent instance with default properties', function ()
    local fl = fluent()

    -- check non-tables
    expect(function ()
      return fl.value, fl.isLazy, fl.isImmutable
    end):toEqual(nil, false, false)

    -- check params
    expect(function ()
      return table.unpack(fl.params)
    end):toEqual(nil)

    -- check queue
    expect(function ()
      return table.unpack(fl.queue)
    end):toEqual(nil)
  end)
end)

describe('Fluent.lazy', function ()
  it('should create a lazy Fluent instance', function ()
    local fl = fluent():lazy()

    expect(function ()
      return fl.isLazy
    end):toEqual(true)
  end)

  it('should add a function to the queue', function ()
    local fl = fluent():lazy()

    local func = function () end

    ---@diagnostic disable-next-line: invisible
    fl:_enqueue(func)

    expect(function ()
      return #fl.queue, fl.queue[1]
    end):toEqual(1, func)
  end)

  it('should not clone the Fluent instance when chaining', function ()
    local fl = fluent():lazy()
    local fl2 = fl:tap(function () end)

    expect(function ()
      return fl2
    end):toEqual(fl)
  end)
end)

describe('Fluent.immutable', function ()
  it('should create an immutable Fluent instance', function ()
    local fl = fluent():immutable()

    expect(function ()
      return fl.isImmutable
    end):toEqual(true)
  end)

  it('should not add a function to the queue', function ()
    local fl = fluent():immutable()

    local func = function () end

    ---@diagnostic disable-next-line: invisible
    fl:_enqueue(func)

    expect(function ()
      return #fl.queue
    end):toEqual(0)
  end)

  it('should clone the Fluent interface', function ()
    local fl = fluent():immutable()

    local fl2 = fl:tap(function () end)

    expect(function ()
      return fl2
    end):toNotEqual(fl)
  end)
end)

describe('Fluent._mutate', function ()
  it('should mutate a mutable Fluent instance', function ()
    local fl = fluent(123)

    ---@diagnostic disable-next-line: invisible
    local fl2 = fl:_mutate(function (this)
      this.value = 456

      return this
    end)

    expect(function ()
      return fl2
    end):toEqual(fl)

    expect(function ()
      return fl.value, fl2.value
    end):toEqual(456, 456)
  end)

  it('should not mutate an immutable Fluent instance', function ()
    local fl = fluent(123):immutable()

    ---@diagnostic disable-next-line: invisible
    local fl2 = fl:_mutate(function (this)
      this.value = 456

      return this
    end)

    expect(function ()
      return fl2
    end):toNotEqual(fl)

    expect(function ()
      return fl.value, fl2.value
    end):toEqual(123, 456)
  end)
end)

describe('Fluent.clone', function ()
  it('should clone a Fluent instance', function ()
    local fl = fluent()
    local fl2 = fl:clone()

    expect(function ()
      return fl2
    end):toNotEqual(fl)
  end)

  it('should clone a Fluent instance with the same properties', function ()
    -- also tests Fluent.fn
    local fl = fluent.fn():from(123):with('param1', 'value1'):tap(function () end)
    local fl2 = fl:clone()

    -- check non-tables
    expect(function ()
      return fl2.value, fl2.isLazy, fl2.isImmutable
    end):toEqual(123, true, true)

    -- check params
    expect(function ()
      return next(fl2.params)
    end):toEqual('param1', 'value1')

    -- check queue (can't check function value due to function wrapping)
    expect(function ()
      return #fl2.queue, type(fl2.queue[1])
    end):toEqual(1, 'function')
  end)
end)

describe('Fluent.with', function ()
  it('should add a parameter to the Fluent instance', function ()
    local fl = fluent():with('param1', 'value1')

    expect(function ()
      return next(fl.params)
    end):toEqual('param1', 'value1')
  end)
end)

describe('Fluent.from', function ()
  it('should set the value of an anonymous Fluent instance', function ()
    local fl = fluent():from(123)

    expect(function ()
      return fl.value
    end):toEqual(123)
  end)

  it('should replace the value of a set Fluent instance', function ()
    local fl = fluent(123):from(456)

    expect(function ()
      return fl.value
    end):toEqual(456)
  end)
end)

describe('Fluent.call', function ()
  it('should call a method on the value', function ()
    local sideEffect = 0

    local obj = {
      causeSideEffect = function ()
        sideEffect = 123

        return 456
      end
    }

    local fl = fluent(obj):call('causeSideEffect')

    expect(function ()
      return sideEffect, fl:result()
    end):toEqual(123, 456)
  end)
end)

describe('Fluent.toBool', function ()
  it('should convert the value to a boolean', function ()
    local fl = fluent():toBool()

    expect(function ()
      return type(fl:result())
    end):toEqual('boolean')
  end)

  it('should convert truthy values to true', function ()
    local flTrue, flNum, flStr = fluent(true):toBool(), fluent(123):toBool(), fluent('abc'):toBool()

    expect(function ()
      return flTrue:result(), flNum:result(), flStr:result()
    end):toEqual(true, true, true)
  end)

  it('should convert falsy values to false', function ()
    local flFalse, flNil = fluent(false):toBool(), fluent(nil):toBool()

    expect(function ()
      return flFalse:result(), flNil:result()
    end):toEqual(false, false)
  end)
end)

describe('Fluent.toFlag', function ()
  it('should convert the value to a flag', function ()
    local fl = fluent():toFlag()

    expect(function ()
      return type(fl:result())
    end):toEqual('number')
  end)

  it('should convert truthy values to 1', function ()
    local flTrue, flNum, flStr = fluent(true):toFlag(), fluent(123):toFlag(), fluent('abc'):toFlag()

    expect(function ()
      return flTrue:result(), flNum:result(), flStr:result()
    end):toEqual(1, 1, 1)
  end)

  it('should convert falsy values to 0', function ()
    local flFalse, flNil = fluent(false):toFlag(), fluent(nil):toFlag()

    expect(function ()
      return flFalse:result(), flNil:result()
    end):toEqual(0, 0)
  end)
end)

describe('Fluent.toLookup', function ()
  local lookup = { key1 = 'value1', key2 = 'value2' }

  it('should convert the value using a lookup table', function ()
    local fl = fluent('key1'):toLookup(lookup)

    expect(function ()
      return fl:result()
    end):toEqual('value1')
  end)

  it('should set value to nil for missing lookup key', function ()
    local fl = fluent('invalid'):toLookup(lookup)

    expect(function ()
      return fl:result()
    end):toEqual(nil)
  end)
end)

describe('Fluent.transform', function ()
  it('should transform the value using a function', function ()
    local fl = fluent(123):transform(function (value)
      return value * 2
    end)

    expect(function ()
      return fl:result()
    end):toEqual(246)
  end)
end)

describe('Fluent.each', function ()
  it('should iterate over a table', function ()
    local iteratedKeys = {}
    local iteratedValues = {}

    local fl = fluent({ 4, 5, 6 }):each(function (k, v)
      table.insert(iteratedKeys, k)
      table.insert(iteratedValues, v)
    end)

    expect(function ()
      return table.unpack(fl:result())
    end):toEqual(4, 5, 6)

    expect(function ()
      return table.unpack(iteratedKeys)
    end):toEqual(1, 2, 3)

    expect(function ()
      return table.unpack(iteratedValues)
    end):toEqual(4, 5, 6)
  end)

  it('should not mutate elements by return value', function ()
    local fl = fluent({ 1, 2, 3 }):each(function (k, v)
      return v * 2
    end)

    expect(function ()
      return table.unpack(fl:result())
    end):toEqual(1, 2, 3)
  end)

  it('should throw if value is not iterable', function ()
    expect(function ()
      fluent(123):each(function () end)
    end):toThrow()
  end)

  it('should stop executing if function returns false', function ()
    local iteratedKeys = {}
    local iteratedValues = {}

    local fl = fluent({ 4, 5, 6 }):each(function (k, v)
      if v == 6 then
        return false
      end

      table.insert(iteratedKeys, k)
      table.insert(iteratedValues, v)
    end)

    expect(function ()
      return table.unpack(fl:result())
    end):toEqual(4, 5, 6)

    expect(function ()
      return table.unpack(iteratedKeys)
    end):toEqual(1, 2)

    expect(function ()
      return table.unpack(iteratedValues)
    end):toEqual(4, 5)
  end)
end)

describe('Fluent.filter', function ()
  it('should filter out falsy values from a list', function ()
    local value = { 1, 2, nil, 'str', '', false, true }

    local fl = fluent(value):immutable():filter()

    expect(function ()
      local result = fl:result()
      local count = fl:values():result()

      return #count, type(result[3]), type(result[6])
    end):toEqual(5, 'nil', 'nil')
  end)

  it('should filter out falsy values from a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = nil, key4 = 'str', key5 = '', key6 = false, key7 = true }

    local fl = fluent(value):immutable():filter()

    expect(function ()
      local result = fl:result()
      local count = fl:values():result()

      return #count, type(result.key3), type(result.key6)
    end):toEqual(5, 'nil', 'nil')
  end)

  it('should filter out values that do not pass a test function', function ()
    local value = { 3, 4, 5, 6 }

    local fl = fluent(value):immutable():filter(function (_, v)
      return v % 2 == 0
    end)

    expect(function ()
      local result = fl:result()
      local count = fl:values():result()

      return #count, type(result[1]), type(result[3])
    end):toEqual(2, 'nil', 'nil')
  end)

  it('should return an empty list if no values are truthy', function ()
    local value = { false, false }

    local fl = fluent(value):filter()

    expect(function ()
      return #fl:values():result()
    end):toEqual(0)
  end)

  it('should return an empty list if no values pass a test function', function ()
    local value = { 2, 4, 6, 8 }

    local fl = fluent(value):filter(function (_, v)
      return v == 5
    end)

    expect(function ()
      return #fl:values():result()
    end):toEqual(0)
  end)
end)

describe('Fluent.filterMatch', function ()
  it('should filter out values that do not pass a test pattern', function ()
    local value = { 'abc', 'def', 'ghi', 'jkl' }

    local fl = fluent(value):immutable():filterMatch('^d')

    expect(function ()
      local result = fl:result()
      local count = fl:values():result()

      return #count, result[2]
    end):toEqual(1, 'def')
  end)

  it('should return an empty list if no values pass a test pattern', function ()
    local value = { 'abc', 'def', 'ghi', 'jkl' }

    local fl = fluent(value):filterMatch('^m')

    expect(function ()
      return #fl:result()
    end):toEqual(0)
  end)
end)

describe('Fluent.filterSub', function ()
  it('should filter out values that do not pass a test subexpression', function ()
    local value = { { a = 1, b = 2, c = 10 }, { a = 3, b = 4, d = 11 }, { a = 5, b = 6, e = 12 } }

    local fl = fluent(value):immutable():filterSub(fluent.fn():has('d'))

    expect(function ()
      local result = fl:result()
      local count = fl:values():result()

      return #count, result[2].d
    end):toEqual(1, 11)
  end)

  it('should return an empty list if no values pass a test subexpression', function ()
    local value = { { a = 1, b = 2, c = 10 }, { a = 3, b = 4, d = 11 }, { a = 5, b = 6, e = 12 } }

    local fl = fluent(value):filterSub(fluent.fn():has('f'))

    expect(function ()
      return #fl:values():result()
    end):toEqual(0)
  end)
end)

describe('Fluent.first', function ()
  it('should return the first element of a list', function ()
    local value = { 1, 2, 3 }

    local fl = fluent(value):first()

    expect(function ()
      return fl:result()
    end):toEqual(1)
  end)

  it('should return nil if the list is empty', function ()
    local value = {}

    local fl = fluent(value):first()

    expect(function ()
      return type(fl:result())
    end):toEqual('nil')
  end)

  -- a silly test because pairs() is non-deterministic
  it('should return a single element of a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):first()

    expect(function ()
      local result = fl:result()

      return result == value.key1 or result == value.key2 or result == value.key3
    end):toEqual(true)
  end)
end)

describe('Fluent.firstWhere', function ()
  it('should return the first element that has the specified key and value', function ()
    local value = { { a = 1, b = 2 }, { a = 3, b = 4 }, { a = 5, b = 6 } }

    local fl = fluent(value):firstWhere('a', 3)

    expect(function ()
      return fl:result().b
    end):toEqual(4)
  end)

  it('should return nil if no element has the specified key and value', function ()
    local value = { { a = 1, b = 2 }, { a = 3, b = 4 }, { a = 5, b = 6 } }

    local fl = fluent(value):firstWhere('a', 7)

    expect(function ()
      return type(fl:result())
    end):toEqual('nil')
  end)

  it('should return nil if the list is empty', function ()
    local value = {}

    local fl = fluent(value):firstWhere('a', 1)

    expect(function ()
      return type(fl:result())
    end):toEqual('nil')
  end)
end)

describe('Fluent.get', function ()
  it('should return the value of a key in a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):get('key2')

    expect(function ()
      return fl:result()
    end):toEqual(2)
  end)

  it('should return nil if the key does not exist', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):get('key4')

    expect(function ()
      return type(fl:result())
    end):toEqual('nil')
  end)

  it('should return the default value if the key does not exist', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value)

    fl:get('key4', 4)

    expect(function ()
      return fl:result()
    end):toEqual(4)
  end)

  it('should return a subvalue of a key in a dictionary', function ()
    local value = { key1 = { key2 = { key3 = 3 } } }

    local fl = fluent(value):get('key1.key2.key3')

    expect(function ()
      return fl:result()
    end):toEqual(3)
  end)

  it('should return nil if the subkey does not exist', function ()
    local value = { key1 = { key2 = { key3 = 3 } } }

    local fl = fluent(value):get('key1.invalid')

    expect(function ()
      return type(fl:result())
    end):toEqual('nil')
  end)

  it('should return the default value if the subkey does not exist', function ()
    local value = { key1 = { key2 = { key3 = 3 } } }

    local fl = fluent(value):get('key1.invalid', 4)

    expect(function ()
      return fl:result()
    end):toEqual(4)
  end)
end)

describe('Fluent.groupBy', function ()
  it('should group elements by a key', function ()
    local value = { { a = 'a1', b = 2 }, { a = 'a1', b = 3 }, { a = 'a2', b = 4 } }

    local fl = fluent(value):groupBy('a')

    expect(function ()
      local result = fl:result()

      return result.a1[1].b, result.a1[2].b, result.a2[1].b
    end):toEqual(2, 3, 4)
  end)

  it('should group elements by a numeric key', function ()
    local value = { { a = 1, b = 2 }, { a = 1, b = 3 }, { a = 2, b = 4 } }

    local fl = fluent(value):groupBy('a')

    expect(function ()
      local result = fl:result()

      return result[1][1].b, result[1][2].b, result[2][1].b
    end):toEqual(2, 3, 4)
  end)
end)

describe('Fluent.has', function ()
  it('should return true if key exists in a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):has('key2')

    expect(function ()
      return fl:result()
    end):toEqual(true)
  end)

  it('should return false if key does not exist in a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):has('key4')

    expect(function ()
      return fl:result()
    end):toEqual(false)
  end)
end)

describe('Fluent.keys', function ()
  it('should return the keys of a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):keys()

    expect(function ()
      return table.unpack(fl:sort():result())
    end):toEqual('key1', 'key2', 'key3')
  end)
end)

describe('Fluent.last', function ()
  it('should return the last element of a list', function ()
    local value = { 1, 2, 3 }

    local fl = fluent(value):last()

    expect(function ()
      return fl:result()
    end):toEqual(3)
  end)

  it('should return nil if the list is empty', function ()
    local value = {}

    local fl = fluent(value):last()

    expect(function ()
      return type(fl:result())
    end):toEqual('nil')
  end)

  it('should return a single element of a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):last()

    expect(function ()
      local result = fl:result()

      return result == value.key1 or result == value.key2 or result == value.key3
    end):toEqual(true)
  end)
end)

describe('Fluent.mapWithKeys', function ()
  it('should map elements with unique keys', function ()
    local value = { { a = 'a1', b = 2 }, { a = 'a3', b = 4 }, { a = 'a5', b = 6 } }

    local fl = fluent(value):mapWithKeys(function (k, v)
      return v.a, v.b
    end)

    expect(function ()
      local result = fl:result()

      return result.a1, result.a3, result.a5
    end):toEqual(2, 4, 6)
  end)

  it('should map elements with duplicate keys', function ()
    local value = { { a = 'a1', b = 2 }, { a = 'a1', b = 4 }, { a = 'a1', b = 6 } }

    local fl = fluent(value):mapWithKeys(function (k, v)
      return v.a, v.b
    end)

    expect(function ()
      return fl:result().a1
    end):toEqual(6)
  end)

  it('should map a dictionary to a list', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):mapWithKeys(function (k, v)
      return v, k
    end)

    expect(function ()
      return table.unpack(fl:sort():result())
    end):toEqual('key1', 'key2', 'key3')
  end)
end)

describe('Fluent.map', function ()
  it('should map a list', function ()
    local value = { 1, 2, 3 }

    local fl = fluent(value):map(function (_, v)
      return v * 2
    end)

    expect(function ()
      return table.unpack(fl:result())
    end):toEqual(2, 4, 6)
  end)

  it('should map a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):map(function (_, v)
      return v * 2
    end)

    expect(function ()
      local result = fl:result()

      return result.key1, result.key2, result.key3
    end):toEqual(2, 4, 6)
  end)

  it('should return an empty list if there are no elements', function ()
    local fl = fluent({}):map(function (_, v) return v end)

    expect(function ()
      return #fl:values():result()
    end):toEqual(0)
  end)
end)

describe('Fluent.mapValues', function ()
  it('should map values of a list', function ()
    local value = { 1, 2, 3 }

    local fl = fluent(value):mapValues(function (v)
      return v * 2
    end)

    expect(function ()
      return table.unpack(fl:result())
    end):toEqual(2, 4, 6)
  end)

  it('should map values of a dictionary', function ()
    local value = { key1 = 3, key2 = 4, key3 = 5 }

    local fl = fluent(value):mapValues(function (v)
      return v * 2
    end)

    expect(function ()
      local result = fl:result()

      return result.key1, result.key2, result.key3
    end):toEqual(6, 8, 10)
  end)

  it('should return an empty list if there are no elements', function ()
    local fl = fluent({}):mapValues(function (v) return v end)

    expect(function ()
      return #fl:values():result()
    end):toEqual(0)
  end)
end)

describe('Fluent.mapSub', function ()
  it('should map values of a list using a subexpression', function ()
    local value = { { a = 1, b = 2 }, { a = 3, b = 4 }, { a = 5, b = 6 } }

    local fl = fluent(value):mapSub(fluent.fn():get('a'))

    expect(function ()
      return table.unpack(fl:result())
    end):toEqual(1, 3, 5)
  end)

  it('should map values of a dictionary using a subexpression', function ()
    local value = { key1 = { a = 1, b = 2 }, key2 = { a = 3, b = 4 }, key3 = { a = 5, b = 6 } }

    local fl = fluent(value):mapSub(fluent.fn():get('a'))

    expect(function ()
      local result = fl:result()

      return result.key1, result.key2, result.key3
    end):toEqual(1, 3, 5)
  end)

  it('should return an empty list if there are no elements', function ()
    local fl = fluent({}):mapSub(fluent.fn():get('a'))

    expect(function ()
      return #fl:values():result()
    end):toEqual(0)
  end)
end)

describe('Fluent.match', function ()
  it('should return a match', function ()
    local fl = fluent('abc'):match('^a')

    expect(function ()
      return fl:result()
    end):toEqual('a')
  end)

  it('should return nil if the value does not match a pattern', function ()
    local fl = fluent('abc'):match('^b')

    expect(function ()
      return type(fl:result())
    end):toEqual('nil')
  end)
end)

describe('Fluent.only', function ()
  it('should return only the specified keys of a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):only({'key1', 'key3'})

    expect(function ()
      local result = fl:result()

      return result.key1, type(result.key2), result.key3
    end):toEqual(1, 'nil', 3)
  end)

  it('should return an empty list if there are no elements', function ()
    local fl = fluent({}):only({'key1', 'key2'})

    expect(function ()
      return #fl:result()
    end):toEqual(0)
  end)

  it('should return only the specified keys of a list', function ()
    local value = { 4, 5, 6 }

    local fl = fluent(value):only({1, 3})

    expect(function ()
      local result = fl:result()

      return result[1], type(result[2]), result[3]
    end):toEqual(4, 'nil', 6)
  end)

  it('should return an empty list if no keys are specified', function ()
    local value = { 4, 5, 6 }

    local fl = fluent(value):only({})

    expect(function ()
      return #fl:result()
    end):toEqual(0)
  end)
end)

describe('Fluent.pluck', function ()
  it('should pluck a key from a list of dictionaries', function ()
    local value = { { a = 1, b = 2 }, { a = 3, b = 4 }, { a = 5, b = 6 } }

    local fl = fluent(value):pluck('a')

    expect(function ()
      return table.unpack(fl:result())
    end):toEqual(1, 3, 5)
  end)

  it('should return an empty list if there are no elements', function ()
    local fl = fluent({}):pluck('a')

    expect(function ()
      return #fl:result()
    end):toEqual(0)
  end)
end)

describe('Fluent.random', function ()
  it('should pick a random element from a list', function ()
    local value = { 1, 2, 3 }

    local fl = fluent(value):random()

    expect(function ()
      local result = fl:result()

      return result == 1 or result == 2 or result == 3
    end):toEqual(true)
  end)

  it('should pick a random element from a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):random()

    expect(function ()
      local result = fl:result()

      return result == 1 or result == 2 or result == 3
    end):toEqual(true)
  end)

  it('should throw if there are no elements', function ()
    expect(function ()
      return fluent({}):random()
    end):toThrow()
  end)

  it('should return multiple random elements from a list', function ()
    local value = { 1, 2, 3 }

    local fl = fluent(value):random(2)

    expect(function ()
      local result = fl:values():result()

      return result[1] ~= result[2] and (result[1] == 1 or result[1] == 2 or result[1] == 3) and (result[2] == 1 or result[2] == 2 or result[2] == 3)
    end):toEqual(true)
  end)
end)

describe('Fluent.reduce', function ()
  it('should reduce a list', function ()
    local value = { 4, 5, 6 }

    local fl = fluent(value):reduce(function (acc, _, v)
      return acc + v
    end, 0)

    expect(function ()
      return fl:result()
    end):toEqual(15)
  end)

  it('should reduce a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):reduce(function (acc, _, v)
      return acc + v
    end, 0)

    expect(function ()
      return fl:result()
    end):toEqual(6)
  end)

  it('should return the initial value if there are no elements', function ()
    local fl = fluent({}):reduce(function (acc, _, v)
      return acc + v
    end, 0)

    expect(function ()
      return fl:result()
    end):toEqual(0)
  end)

  it('should reduce a list with keys', function ()
    local value = { 4, 5, 6 }

    local fl = fluent(value):reduce(function (acc, k, v)
      return acc + k + v
    end, 0)

    expect(function ()
      return fl:result()
    end):toEqual(21)
  end)
end)

describe('Fluent.reject', function ()
  it('should filter out truthy values from a list', function ()
    local value = { 1, 2, nil, 'str', '', false, true }

    local fl = fluent(value):immutable():reject()

    expect(function ()
      local result = fl:result()
      local count = fl:values():result()

      return #count, type(result[3]), result[6]
    end):toEqual(1, 'nil', false)
  end)

  it('should filter out truthy values from a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = nil, key4 = 'str', key5 = '', key6 = false, key7 = true }

    local fl = fluent(value):immutable():reject()

    expect(function ()
      local result = fl:result()
      local count = fl:values():result()

      return #count, type(result.key3), result.key6
    end):toEqual(1, 'nil', false)
  end)

  it('should filter out values that pass a test function', function ()
    local value = { 3, 4, 5, 6 }

    local fl = fluent(value):immutable():reject(function (_, v)
      return v % 2 == 0
    end)

    expect(function ()
      local result = fl:result()
      local count = fl:values():result()

      return #count, type(result[2]), type(result[4])
    end):toEqual(2, 'nil', 'nil')
  end)

  it('should return an empty list if no values are falsy', function ()
    local value = { true, 1, 'minions movie' }

    local fl = fluent(value):reject()

    expect(function ()
      return #fl:values():result()
    end):toEqual(0)
  end)

  it('should return an empty list if all values pass a test function', function ()
    local value = { 2, 4, 6, 8 }

    local fl = fluent(value):reject(function (_, v)
      return v % 2 == 0
    end)

    expect(function ()
      return #fl:values():result()
    end):toEqual(0)
  end)
end)

describe('Fluent.replace', function ()
  it('should replace key-value pairs in a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):immutable():replace({ key2 = 222 })

    expect(function ()
      local result = fl:result()
      local count = fl:values():result()

      return #count, result.key1, result.key2, result.key3
    end):toEqual(3, 1, 222, 3)
  end)

  it('should replace key-value pairs in a list', function ()
    local value = { 1, 2, 3 }

    local fl = fluent(value):immutable():replace({ 111 })

    expect(function ()
      local result = fl:result()
      local count = fl:values():result()

      return #count, table.unpack(result)
    end):toEqual(3, 111, 2, 3)
  end)

  it('should return the same list if no replacements are provided', function ()
    local value = { 1, 2, 3 }

    local fl = fluent(value):immutable():replace({})

    expect(function ()
      return table.unpack(fl:result())
    end):toEqual(1, 2, 3)
  end)
end)

describe('Fluent.select', function ()
  it('should select keys from a list of dictionaries', function ()
    local value = { { a = 1, b = 2, c = 3 }, { a = 4, b = 5, c = 6 } }

    local fl = fluent(value):select({'a', 'c'})

    expect(function ()
      local result = fl:result()

      return result[1].a, type(result[1].b), result[1].c, result[2].a, type(result[2].b), result[2].c
    end):toEqual(1, 'nil', 3, 4, 'nil', 6)
  end)

  it('should select keys from a list of lists', function ()
    local value = { { 1, 2, 3 }, { 4, 5, 6 } }

    local fl = fluent(value):select({1, 3})

    expect(function ()
      local result = fl:result()

      return result[1][1], type(result[1][2]), result[1][3], result[2][1], type(result[2][2]), result[2][3]
    end):toEqual(1, 'nil', 3, 4, 'nil', 6)
  end)

  it('should return an empty list if there are no elements', function ()
    local fl = fluent({}):select({'a', 'b'})

    expect(function ()
      return #fl:result()
    end):toEqual(0)
  end)
end)

describe('Fluent.sort', function ()
  it('should sort a list', function ()
    local value = { 3, 1, 2 }

    local fl = fluent(value):sort()

    expect(function ()
      return table.unpack(fl:result())
    end):toEqual(1, 2, 3)
  end)

  it('should sort a list with a function', function ()
    local value = { 3, 1, 2 }

    local fl = fluent(value):sort(function (a, b)
      return a > b
    end)

    expect(function ()
      return table.unpack(fl:result())
    end):toEqual(3, 2, 1)
  end)
end)

describe('Fluent.sortBy', function ()
  it('should sort a list by a key', function ()
    local value = { { a = 3 }, { a = 1 }, { a = 2 } }

    local fl = fluent(value):sortBy('a')

    expect(function ()
      local result = fl:result()

      return result[1].a, result[2].a, result[3].a
    end):toEqual(1, 2, 3)
  end)
end)

describe('Fluent.sum', function ()
  it('should sum a list', function ()
    local value = { 1, 2, 3 }

    local fl = fluent(value):sum()

    expect(function ()
      return fl:result()
    end):toEqual(6)
  end)

  it('should sum a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):sum()

    expect(function ()
      return fl:result()
    end):toEqual(6)
  end)

  it('should sum a list of dictionaries by key', function ()
    local value = { { a = 5, b = 5 }, { a = 8, b = 88 }, { a = 8, b = 888 } }

    local fl = fluent(value):sum('a')

    expect(function ()
      return fl:result()
    end):toEqual(21)
  end)

  it('should sum a list of dictionaries by key and group', function ()
    local value = { { a = 'group5', b = 5 }, { a = 'group8', b = 88 }, { a = 'group8', b = 888 } }

    local fl = fluent(value):sum('b', 'a')

    expect(function ()
      local result = fl:result()

      return result.group5, result.group8
    end):toEqual(5, 976)
  end)
end)

describe('Fluent.tap', function ()
  it('should call a function with the value', function ()
    local sideEffect = 0

    fluent(123):tap(function (value)
      sideEffect = value
    end)

    expect(function ()
      return sideEffect
    end):toEqual(123)
  end)
end)

describe('Fluent.values', function ()
  it('should reindex a list', function ()
    local value = { [4] = 9, [9] = 8, [2] = 7 }

    local fl = fluent(value):immutable():values()

    expect(function ()
      local result = fl:result()
      local keys = fl:keys():result()

      return result[1] + result[2] + result[3], table.unpack(keys)
    end):toEqual(24, 1, 2, 3)
  end)

  it('should reindex a dictionary', function ()
    local value = { key1 = 1, key2 = 2, key3 = 3 }

    local fl = fluent(value):immutable():values()

    expect(function ()
      local result = fl:result()
      local keys = fl:keys():result()

      return result[1] + result[2] + result[3], table.unpack(keys)
    end):toEqual(6, 1, 2, 3)
  end)
end)

test()