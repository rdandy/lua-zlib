print "1..6"

local tap   = require("tap")
local lz    = require("zlib")
local ok    = tap.ok

function main()
   test_basic()
   test_large()
   test_no_input()
   test_invalid_input()
   test_streaming()
   test_illegal_state()
end

function test_basic()
   local test_string = "abcdefghijklmnopqrstuv"

   -- Input to deflate is same as output to inflate:
   local deflated = lz.deflate()(test_string, "finish")
   local inflated = lz.inflate()(deflated, "finish")

   ok(test_string == inflated, "'" .. tostring(test_string) .. "' == '" .. tostring(inflated) .. "'")
end

function test_large()
   -- Try a larger string:
   local numbers = ""
   for i=1, 100 do numbers = numbers .. string.format("%3d", i) end
   local numbers_table = {}
   for i=1, 10000 do numbers_table[i] = numbers end
   local test_string = table.concat(numbers_table, "\n")

   local deflated = lz.deflate()(test_string, "finish")
   local inflated = lz.inflate()(deflated, "finish")
   ok(test_string == inflated, "large string")
end

function test_no_input()
   local stream = lz.deflate()
   local deflated = stream("")
   deflated = deflated .. stream("")
   deflated = deflated .. stream(nil, "finish")
   ok("" == lz.inflate()(deflated, "finish"), "empty string")
end

function test_invalid_input()
   local stream = lz.inflate()
   local _, emsg = pcall(
      function()
         stream("bad input")
      end)
   ok(string.find(emsg, "^InvalidInput"),
      string.format("InvalidInput error (%s)", emsg))
end

function test_streaming()
   local shrink     = lz.deflate(lz.BEST_COMPRESSION)
   local enlarge    = lz.inflate()
   local expected   = {}
   local got        = {} 
   local chant      = "Isn't He great, isn't He wonderful?\n"
   for i=1,100 do
      if ( i == 100 ) then
         chant = nil
         print "EOF round"
      end
      local shrink_part, shrink_eof   = shrink(chant)
      local enlarge_part, enlarge_eof = enlarge(shrink_part)
      if ( i == 100 ) then
         if not shrink_eof  then error("expected eof after shrinking flush") end
         if not enlarge_eof then error("expected eof after enlarging") end
      else
         if shrink_eof  then error("unexpected eof after shrinking") end
         if enlarge_eof then error("unexpected eof after enlarging") end
      end
      if enlarge_part then table.insert(got, enlarge_part) end
      if chant        then table.insert(expected, chant) end
   end
   ok(table.concat(got) == table.concat(expected), "streaming works")
end

function test_illegal_state()
   local stream = lz.deflate()
   stream("abc")
   stream() -- eof/close

   local _, emsg = pcall(
      function()
         stream("printing on 'closed' handle")
      end)
   ok(string.find(emsg, "^IllegalState"),
      string.format("IllegalState error (%s)", emsg))
   
   local enlarge = lz.inflate()
end

main()