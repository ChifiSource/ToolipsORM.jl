mutable struct ChiDBDriver{T} <: AbstractCursorDriver
    stream::T
    transaction::Char
end

function ORM(func::Function, driver::Type{ChiDBDriver},
        host::IP4, user::String, pwd::String, key::String)
    curs = ChiDBDriver{Nothing}(nothing, 'a')
    ORM{ChiDBDriver}(host, user => pwd, key, func, curs)::ORM{ChiDBDriver}
end

function ORM(driver::Type{ChiDBDriver}, host::IP4, user::String, pwd::String, key::String; keys ...)
    func = () -> (user, pwd, key)
    ORM(func, driver, host, user, pwd, key; keys ...)
end

make_argstring(orm::ORM{<:Any}, val::Any) = string(val)::String

make_argstring(orm::ORM{<:Any}, val::AbstractVector) = join((string(v) for v in val), "!;")::String

function command_translate(driver::ChiDBDriver, command::AbstractString)
    pairs = Dict{String, Char}("userlist" => 'U', "newuser" => 'C', 
        "setuser" => 'K', "logout" => 'L', "rmuser" => 'D', "list" => 'l', 
        "select" => 's', "create" => 't', "get" => 'g', "getrow" => 'r', 
        "index" => 'i', "store" => 'a', "set" => 'v', "setrow" => 'w', 
        "join" => 'j', "type" => 'k', "rename" => 'e', "deleteat" => 'd', 
        "delete" => 'z', "compare" => 'p', "in" => 'n', "columns" => 'o')
    if ~(command in keys(pairs))
        throw("ORM command error")
    end
    pairs[command]::Char
end

function connect!(orm::ORM{ChiDBDriver})
    if orm.login[1] == ""
        new_login = orm.get()
        if length(new_login) != 3
            throw("future ORM error")
        end
        orm.login = new_login[1] => new_login[2]
        orm.dbkey = new_login[3]
    end
    cursor_stream = try
        Toolips.connect(orm.host)
    catch
        # TODO future ORMConnectError
        throw("future connect error")
    end
    outgoing = "eS$(orm.dbkey) $(orm.login[1]) $(orm.login[2])\n"
    @info outgoing
    write!(cursor_stream, outgoing)
    response::String = ""
    while true
        response = response * String(readavailable(cursor_stream))
        if length(response) > 1 && response[end] == '\n'
            break
        end
    end
    header = bitstring(UInt8(response[1]))
    opcode = header[1:4]
    if opcode == "0001"
        @info "connected"
        #success
    elseif opcode == "1100"
        throw("future connect error bad login")
    elseif opcode == "1010"
        throw("db key error")
    end
    orm.cursor = ChiDBDriver{TCPSocket}(cursor_stream, response[1])
    nothing::Nothing
end


query(orm::ORM{ChiDBDriver}, cmd::Char, args::Any ...) = begin 
    ret = query(String, orm, cmd, args ...)
    ret = replace(ret, "\n" => "")
    has_array = contains(ret, "!;")
    if contains(ret, "!;")
        if contains(ret, "!N")
            return(hcat((split(row, "!;") for row in split(ret, "!N")) ...))
        else
            return(split(ret, "!;"))
        end
    elseif is_numerical(ret)
        return(parse(Int64, ret))
    elseif is_numerical_float(ret)
        return(parse(Float64, ret))
    end
    return(ret)
end

query(orm::ORM{ChiDBDriver}, cmd::String, args::Any ...) = begin
    query(orm, command_translate(orm.cursor, cmd), args ...)
end

query(t::Type{<:Any}, orm::ORM{ChiDBDriver}, cmd::String, args::Any ...) = begin
    query(t, orm, command_translate(orm.cursor, cmd), args ...)
end

query(t::Type{String}, orm::ORM{ChiDBDriver}, cmd::Char, args::Any ...) = begin
    args = join((make_argstring(orm, arg) for arg in args), "|!|")
    @info args
    querstr = "$(orm.cursor.transaction)$(cmd)$args\n"
    @warn querstr
    write!(orm.cursor.stream, querstr)
    response::String = ""
    while true
        if eof(orm.cursor.stream)
            throw("future connection error")
        end
        response = response * String(readavailable(orm.cursor.stream))
        if length(response) > 1 && response[end] == '\n'
            break
        end
    end
    header = bitstring(UInt8(response[1]))
    opcode = header[1:4]
    @warn "OPCODE: $opcode"
    if opcode == "1110"
        orm.cursor.transaction = response[1]
        throw("ORM command error")
    elseif opcode == "1010"
        errorinfo = ""
        if length(response) > 2
            errorinfo = response[begin + 2:end]
        end
        orm.cursor.transaction = Char(UInt8(response[1]))
        throw("ORM argument error " * errorinfo)
    elseif opcode == "1111"
        @warn "bad transaction! reconnecting ORM"
        connect!(orm)
        return(query(t, orm, cmd, args ...))
    end
    orm.cursor.transaction = response[1]
    @warn bitstring(UInt8(response[1]))
    if length(response) > 1
        return(replace(response[3:end], "!N" => "\n"))
    else
        return("")
    end
end

query(T::Type{<:Number}, orm::ORM{ChiDBDriver}, cmd::String, args::Any ...) = begin
    cmd = command_translate(orm.cursor, cmd)
    res = query(String, orm, cmd, args ...)
    res = replace(res, "\n" => "")
    parse(T, res)::T
end

query(T::Type{<:AbstractVector}, orm::ORM{ChiDBDriver}, args::Any ...) = begin
    res = query(String, orm, args ...)
    this_T = T.parameters[1] <: Number
    is_num = 
    [begin
        if this_T
            parse(this_T, spl)
        else
            this_T(spl)
        end
    end for spl in split(res, "!;")]::Vector{this_T}
end

getindex(orm::ORM{ChiDBDriver}, axis::String, r::UnitRange{Int64} = 0:1) = begin
    if r == 0:1
        query(Vector{String}, orm, 'g', axis)
    else
        query(Vector{String}, orm, 'g', axis, r)
    end
end

push!(orm::ORM{ChiDBDriver}, table::String, vals::Any ...) = begin
    query(String, ORM, table, make_argstring([vals ...]))
end