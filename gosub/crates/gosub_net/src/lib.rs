//! Networking functionality
//!
//! This module contains all the networking functionality for the browser. This is normally the
//! lowlevel implementation of the browser. The networking module is responsible for making HTTP
//! requests, parsing the response and returning the result to the caller.
//!
//! It also contains additional networking components like the DNS resolver.
pub mod dns;
pub mod errors;
pub mod http;

#[macro_use]
extern crate gosub_config;
