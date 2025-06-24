module ToolipsORM
using Toolips
import Toolips: on_start, getindex, setindex!
using Toolips.Sockets: TCPSocket

abstract type AbstractCursorDriver end

mutable struct FFDriver{T} <: AbstractCursorDriver
    stream::T
    transaction::Char
end

struct APIDriver{T} <: AbstractCursorDriver
    url::String
end

const FF = FFDriver

function command_translate(driver::FFDriver, command::AbstractString)
    pairs = Dict{String, Char}("select" => 's', "join" => 'j', 
        "joinref" => 'b', "get" => 'c', "row" => 'w', 
        "value" => 'v', "list" => 'l', "index" => 'g', 
        "deleteat" => 'd', "table" => 't', "delete" => 'z', 
        "view" => 'm', "collist" => 'x', "type" => 'n', 
        "cmp" => 'p', "in" => 'i', "store" => 'a', "rename" => 'r')
    if ~(command in keys(pairs))
        throw("ORM command error")
    end
    pairs[command]::Char
end

mutable struct ORM{T <: AbstractCursorDriver} <: Toolips.AbstractExtension
    host::IP4
    login::Pair{String, String}
    dbkey::String
    get::Function
    cursor::T
end

function ORM(func::Function, driver::Type{FFDriver},
        host::IP4, user::String, pwd::String, key::String)
    curs = FFDriver{Nothing}(nothing, 'a')
    ORM{FFDriver}(host, user => pwd, key, func, curs)::ORM{FFDriver}
end

function ORM(host::IP4, driver::Type{FFDriver}, user::String, pwd::String, key::String; keys ...)
    func = () -> (user, pwd, key)
    ORM(func, driver, host, user, pwd, key; keys ...)
end

function query end

query(orm::ORM{<:Any}, args::Any...) = begin
    throw("this form of query does not work with this ORM type, or querying is not yet implemented for this type.")
end

query(t::Type{<:Any}, orm::ORM{<:Any}, args::Any...) = begin
    throw("this form of query does not work with this ORM type, or querying is not yet implemented for this type.")
end


function connect! end

connect!(orm::ORM{<:Any}) = throw("Not implemented")

#== FF !
==#
function on_start(ext::ORM{FFDriver}, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute})
    push!(data, :ORM => ext)
end


function connect!(orm::ORM{FFDriver})
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
    header = bitstring(response[1])
    opcode = header[1:4]
    if opcode == "0001"
        @info "connected"
        #success
    elseif opcode == "1100"
        throw("future connect error bad login")
    elseif opcode == "1010"
        throw("db key error")
    end
    orm.cursor = FFDriver{TCPSocket}(cursor_stream, response[1])
    nothing::Nothing
end

query(orm::ORM{FFDriver}, cmd::Char, args::Any ...) = begin 
    # TODO Parametrically assume type based on command?
    query(String, orm, cmd, args ...)
end

query(t::Type{String}, orm::ORM{FFDriver}, cmd::Char, args::Any ...) = begin
    args = join((string(arg) for arg in args), "|!|")
    querstr = "$(orm.cursor.transaction)$(cmd)$args\n"
    @warn querstr
    write!(orm.cursor.stream, querstr)
    response::String = ""
    while true
        response = response * String(readavailable(orm.cursor.stream))
        if length(response) > 1 && response[end] == '\n'
            break
        end
    end
    header = bitstring(response[1])
    opcode = header[1:4]
    if opcode == "1110"
        throw("ORM command error")
    elseif opcode == "1010"
        errorinfo = ""
        if length(response) > 1
            errorinfo = response[2:end]
        end
        throw("ORM argument error " * errorinfo)
    elseif opcode == "1111"
        @warn "bad transaction! reconnecting ORM"
        connect!(orm)
    end
    orm.cursor.transaction = response[1]
    @warn bitstring(response[1])
    if length(response) > 1
        return(response[3:end])
    else
        return("")
    end
end

query(t::Type{String}, orm::ORM{FFDriver}, str::String) = begin
    splts = split(str, " ")
    cmd::Char = command_translate(orm.cursor, splts[1])
    query(t, orm, cmd, splts[2:end] ...)
end

query(t::Type{Vector}, orm::ORM{FFDriver}, cmd::Char, args::String ...) = begin

end

query_show(t::Type{Vector}, orm::ORM{FFDriver}, cmd::Char, args::String ...) = begin

end


ORM_API = Toolips.QuickExtension{:ORMAPI}()

function on_start(ext::Toolips.QuickExtension{:ORMAPI}, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute})
    
end

export connect, query, connect!, IP4
end # module ToolipsORM
