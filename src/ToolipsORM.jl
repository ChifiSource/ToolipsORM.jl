module ToolipsORM
using Toolips
import Toolips: on_start

abstract type AbstractDataCursor end

struct FFCursor{T} <: AbstractDataCursor
    stream::T
end

struct APICursor{T} <: AbstractDataCursor
    url::String
end

mutable struct ORM{T <: AbstractDataCursor} <: Toolips.AbstractExtension
    host::IP4
    login::Pair{String, String}
    dbkey::String
    get::Function
    cursor::T
end

function ORM{T}(func::Function, host::IP4, args::String ...) where {T == :ff}
    curs = FFCursor{Nothing}(nothing)
    ORM{FFCursor}(host, args[1] => args[2], args[3], func, curs)::ORM{FFCursor}
end

function ORM{T}(host::IP4, args ...; keys ...) where {T == :ff}
    func = () -> (args[1], args[2], args[3])
    ORM{T}(func, host, args ...; keys ...)
end

function connect!(orm::ORM{FFCursor})
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
    orm.curs = FFCursor{TCPSocket}(cursor_stream)
end

function make_orm_api(orm::ORM{FFCursor})

end

end # module ToolipsORM
