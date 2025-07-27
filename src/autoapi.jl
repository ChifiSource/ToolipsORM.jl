struct ORMAPI{T <: AbstractCursorDriver} <: Toolips.AbstractExtension 
    orm::ORM{T}
end

function on_start(ext::Toolips.QuickExtension{:ORMAPI}, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute})
    
end