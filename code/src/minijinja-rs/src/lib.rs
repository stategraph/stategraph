// lib.rs - Rust wrapper for MiniJinja with C interface

use minijinja::Environment;
use minijinja::UndefinedBehavior;
use serde_json::Value;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

#[repr(C)]
pub struct RenderResult {
    pub success: bool,
    pub data: *mut c_char,
}

#[no_mangle]
pub extern "C" fn minijinja_render_template(
    template_str: *const c_char,
    json_str: *const c_char,
) -> RenderResult {
    // Check for null pointers
    if template_str.is_null() || json_str.is_null() {
        let error_msg = CString::new("Null pointer provided").unwrap();
        return RenderResult {
            success: false,
            data: error_msg.into_raw(),
        };
    }

    // Convert C strings to Rust strings
    let template = match unsafe { CStr::from_ptr(template_str) }.to_str() {
        Ok(s) => s,
        Err(_) => {
            let error_msg = CString::new("Invalid UTF-8 in template string").unwrap();
            return RenderResult {
                success: false,
                data: error_msg.into_raw(),
            };
        }
    };

    let json = match unsafe { CStr::from_ptr(json_str) }.to_str() {
        Ok(s) => s,
        Err(_) => {
            let error_msg = CString::new("Invalid UTF-8 in JSON string").unwrap();
            return RenderResult {
                success: false,
                data: error_msg.into_raw(),
            };
        }
    };

    // Parse JSON
    let context: Value = match serde_json::from_str(json) {
        Ok(value) => value,
        Err(e) => {
            let error_msg = CString::new(format!("JSON parse error: {}", e)).unwrap();
            return RenderResult {
                success: false,
                data: error_msg.into_raw(),
            };
        }
    };

    // Create environment and add template
    let mut env = Environment::new();
    env.set_undefined_behavior(UndefinedBehavior::Strict);
    if let Err(e) = env.add_template("template", template) {
        let error_msg = CString::new(format!("Template parse error: {}", e)).unwrap();
        return RenderResult {
            success: false,
            data: error_msg.into_raw(),
        };
    }

    // Get template and render
    match env.get_template("template") {
        Ok(tmpl) => match tmpl.render(&context) {
            Ok(result) => {
                // Strip interior NUL bytes before building the C string. A rendered
                // template can legitimately contain a NUL (e.g. an OpenTofu plan diff
                // that surfaces a base64gzip'd EC2 user_data blob — gzip magic + NULs),
                // and CString::new rejects any interior NUL. The previous
                // `.replace('\0', "\0")` was a no-op (NUL -> NUL), so `.unwrap()`
                // still panicked with NulError and took the whole process down. NUL
                // bytes cannot be represented in a C string regardless, so drop them.
                let data = CString::new(result.replace('\0', "")).unwrap();
                return RenderResult {
                    success: true,
                    data: data.into_raw(),
                };
            }
            Err(e) => {
                let error_msg = CString::new(format!("Render error: {}", e)).unwrap();
                return RenderResult {
                    success: false,
                    data: error_msg.into_raw(),
                };
            }
        },
        Err(e) => {
            let error_msg = CString::new(format!("Template error: {}", e)).unwrap();
            return RenderResult {
                success: false,
                data: error_msg.into_raw(),
            };
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn minijinja_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        let _ = CString::from_raw(ptr);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Drive the FFI entry point exactly as the OCaml caller does, returning
    /// (success, rendered_output).
    fn render(template: &str, json: &str) -> (bool, String) {
        let t = CString::new(template).unwrap();
        let j = CString::new(json).unwrap();
        let res = minijinja_render_template(t.as_ptr(), j.as_ptr());
        let out = unsafe { CStr::from_ptr(res.data) }
            .to_str()
            .expect("output is valid UTF-8")
            .to_owned();
        unsafe { minijinja_free_string(res.data) };
        (res.success, out)
    }

    #[test]
    fn renders_a_normal_template() {
        let (ok, out) = render("Hello {{ name }}", r#"{"name": "world"}"#);
        assert!(ok);
        assert_eq!(out, "Hello world");
    }

    /// Regression for the CString NulError panic: a rendered value containing an
    /// interior NUL byte — as an OpenTofu plan diff does when it surfaces a
    /// base64gzip'd EC2 user_data blob (gzip magic + NULs) — must not crash the
    /// FFI. Before the fix, `CString::new(result.replace('\0', "\0"))` (a
    /// NUL->NUL no-op) hit NulError and `.unwrap()` aborted the whole process.
    #[test]
    fn interior_nul_byte_is_stripped_not_panicked() {
        let (ok, out) = render("{{ x }}", r#"{"x": "a\u0000b"}"#);
        assert!(ok, "render must succeed instead of panicking on the NUL byte");
        assert_eq!(out, "ab", "the interior NUL must be dropped from the output");
    }
}
