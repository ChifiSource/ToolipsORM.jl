module ToolipsORM
using Toolips
import Toolips: on_start, getindex, setindex!
using Toolips.Sockets: TCPSocket

abstract type AbstractCursorDriver end

struct APIDriver{T} <: AbstractCursorDriver
    url::String
end

function is_numerical(str::AbstractString)
    nums = ('0', '1', '2', '3' , '4', '5', '6', '7', '8', '9')
    f = findfirst(x -> ~(x in nums), str)
    isnothing(f)
end

function is_numerical_float(str::AbstractString)
    nums = ('0', '1', '2', '3' , '4', '5', '6', '7', '8', '9', '.')
    f = findfirst(x -> ~(x in nums), str)
    if isnothing(f) && length(findall(".", str)) == 1
        true
    else
        false
    end
end

mutable struct ORM{T <: AbstractCursorDriver} <: Toolips.AbstractExtension
    host::IP4
    login::Pair{String, String}
    dbkey::String
    get::Function
    cursor::T
end

function query end

query(orm::ORM{<:Any}, args::Any...) = begin
    throw("this form of query does not work with this ORM type, or querying is not yet implemented for this type.")
end

query(t::Type{<:Any}, orm::ORM{<:Any}, args::Any...) = begin
    throw("this form of query does not work with this ORM type, or querying is not yet implemented for this type.")
end

function on_start(ext::ORM{<:Any}, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute})
    if isnothing(ext.driver.stream) || eof(ext.driver.stream)
        connect!(ext)
    end
    push!(data, :ORM => ext)
end

include("featurefile.jl")

function connect! end

connect!(orm::ORM{<:Any}) = throw("Not implemented")

include("autoapi.jl")
export connect, query, connect!, IP4
end # module ToolipsORM
