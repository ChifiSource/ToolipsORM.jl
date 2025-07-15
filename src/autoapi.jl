ORM_API = Toolips.QuickExtension{:ORMAPI}()

struct ORMAPI <: Toolips.AbstractExtension end


function on_start(ext::Toolips.QuickExtension{:ORMAPI}, data::Dict{Symbol, Any}, routes::Vector{<:AbstractRoute})
    
end