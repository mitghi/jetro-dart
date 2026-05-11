//! C ABI for jetro-core. Consumed by Dart via dart:ffi.
//!
//! Object model:
//!   - `jetro_new(ptr,len) -> *mut JetroHandle`    parse JSON bytes
//!   - `jetro_collect(h, expr_ptr, expr_len) -> *mut JetroResult`
//!         result holds either JSON bytes (success) or error string
//!   - `jetro_result_ok(*JetroResult) -> i32`
//!   - `jetro_result_data(*JetroResult) -> *const u8`
//!   - `jetro_result_len(*JetroResult) -> usize`
//!   - `jetro_result_free(*JetroResult)`
//!   - `jetro_free(*JetroHandle)`
//!
//! All strings are passed as (ptr,len) pairs. No null termination required.
//! Returned bytes live until corresponding free fn called.

use std::slice;

use jetro_core::Jetro;

pub struct JetroHandle {
    inner: Jetro,
}

pub struct JetroResult {
    ok: bool,
    payload: Vec<u8>,
}

#[no_mangle]
pub unsafe extern "C" fn jetro_new(ptr: *const u8, len: usize) -> *mut JetroHandle {
    if ptr.is_null() {
        return std::ptr::null_mut();
    }
    let bytes = slice::from_raw_parts(ptr, len).to_vec();
    match Jetro::from_bytes(bytes) {
        Ok(inner) => Box::into_raw(Box::new(JetroHandle { inner })),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn jetro_free(h: *mut JetroHandle) {
    if !h.is_null() {
        drop(Box::from_raw(h));
    }
}

#[no_mangle]
pub unsafe extern "C" fn jetro_collect(
    h: *mut JetroHandle,
    expr_ptr: *const u8,
    expr_len: usize,
) -> *mut JetroResult {
    if h.is_null() || expr_ptr.is_null() {
        return result_err("null pointer");
    }
    let handle = &*h;
    let expr_bytes = slice::from_raw_parts(expr_ptr, expr_len);
    let expr = match std::str::from_utf8(expr_bytes) {
        Ok(s) => s,
        Err(_) => return result_err("expression is not valid UTF-8"),
    };
    match handle.inner.collect(expr) {
        Ok(v) => match serde_json::to_vec(&v) {
            Ok(bytes) => Box::into_raw(Box::new(JetroResult {
                ok: true,
                payload: bytes,
            })),
            Err(e) => result_err(&e.to_string()),
        },
        Err(e) => result_err(&e.to_string()),
    }
}

fn result_err(msg: &str) -> *mut JetroResult {
    Box::into_raw(Box::new(JetroResult {
        ok: false,
        payload: msg.as_bytes().to_vec(),
    }))
}

#[no_mangle]
pub unsafe extern "C" fn jetro_result_ok(r: *const JetroResult) -> i32 {
    if r.is_null() {
        return 0;
    }
    if (*r).ok {
        1
    } else {
        0
    }
}

#[no_mangle]
pub unsafe extern "C" fn jetro_result_data(r: *const JetroResult) -> *const u8 {
    if r.is_null() {
        return std::ptr::null();
    }
    (*r).payload.as_ptr()
}

#[no_mangle]
pub unsafe extern "C" fn jetro_result_len(r: *const JetroResult) -> usize {
    if r.is_null() {
        return 0;
    }
    (*r).payload.len()
}

#[no_mangle]
pub unsafe extern "C" fn jetro_result_free(r: *mut JetroResult) {
    if !r.is_null() {
        drop(Box::from_raw(r));
    }
}
