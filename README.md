<div align="center">
 <img src="https://github.com/ChifiSource/image_dump/blob/main/toolips/toolipsORM.png"></img>
 </div>
 
###### multi-use ORM system for Toolips
`ToolipsORM` provides `Toolips` with a parametric Object-Relational-Management (ORM) system using the `AbstractDriver` and `ORM` types. This package features structure-like remote data-base indexing alongside a querying framework and query wrapper. All of this is designed with extensibility and versatility in mind, making the implementation of new or *translated* drivers incredibly straightforward.
```julia
using Pkg
Pkg.add("ToolipsORM")
```
- [0.1.0 notes](#notes)
- [documentation]()
- [basic usage]()
  - [ORM]()
  - [connecting]()
  - [querying]()

### notes
Version `0.1.0` of `ToolipsORM` is built *exclusively* to create the first querying framework for the [ChiDB](https://github.com/ChifiSource/ChiDB.jl) database server. This project is planned to eventually encompass a much wider subset of drivers, though even the current iteration makes it incredibly easy to implement them yourself. As of this version, only the `FFDriver` and the `APIDriver` are available.
###### documentation

## basic usage

###### orm
###### querying
