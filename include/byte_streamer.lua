---@diagnostic disable

do
    byte_streamer = {}
    local _ENV = rescope(byte_streamer, _ENV)
    -- source = nil
    -- offset = 0
    -- source can be:
    --   integer: location in memory
    --   string: an ascii string
    --   table: a list of integers

    function set_source(src, pos)
        source, offset = src, pos or 0
    end

    function write(...)
        assert(source)

        local bytes = { ... }
        if type(source) == "number" then
            poke(source + offset, ...)
        elseif type(source) == "string" then
            source = sub(source, 1, offset) .. chr(...) .. sub(source, offset + #bytes + 1)
        elseif type(source) == "table" then
            for i, byte in ipairs(bytes) do
                source[offset + i] = byte
            end
        end
        offset = offset + #bytes
    end

    function read(num)
        assert(source)
        local o = offset
        num = num or 1
        offset = offset + num
        if type(source) == "number" then
            return peek(source + o, num)
        elseif type(source) == "string" then
            return ord(source, o + 1, num)
        elseif type(source) == "table" then
            local ret = {}
            for i = 1, num do
                add(ret, source[o + i])
            end
            return unpack(ret)
        end
    end

    function write_str(str)
        write(#str, ord(str, 1, #str))
    end

    function read_str()
        return chr(read(read()))
    end

    function write_bin(bin_tbl)
        local num = 0
        for i = 0, 7 do
            num = num + (bin_tbl[i + 1] and 1 << i or 0)
        end
        write(num)
    end

    function read_bin()
        local num = read()
        local ret = {}
        for i = 0, 7 do
            ret[i + 1] = num & 1 << i ~= 0
        end
        return ret
    end
end
