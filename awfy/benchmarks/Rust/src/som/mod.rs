// The suite's own library (upstream C++ src/som/), as core-language.md requires: "we use a common
// library implemented within the core language subset of each language", never the language's
// built-in collections' algorithms. Storage is a `Vec` used as the fixed-size array C++ manages with
// `new E[n]`: the growth policy, the indices and every loop are the suite's, not `Vec`'s.
// The library is upstream's whole interface, so some of it is unused by these benchmarks, as in C++.
#![allow(dead_code)]

pub mod dictionary;
pub mod random;
pub mod set;
pub mod vector;

pub use dictionary::{CustomHash, IdentityDictionary};
pub use random::Random;
pub use set::{IdentitySet, Set};
pub use vector::Vector;
