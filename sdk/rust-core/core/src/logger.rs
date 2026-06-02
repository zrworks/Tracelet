#[cfg(target_os = "android")]
use std::ffi::CString;

#[cfg(target_os = "android")]
#[link(name = "log")]
extern "C" {
    pub fn __android_log_write(
        prio: std::os::raw::c_int,
        tag: *const std::os::raw::c_char,
        text: *const std::os::raw::c_char,
    );
}

pub fn info(msg: &str) {
    #[cfg(target_os = "android")]
    {
        if let Ok(c_tag) = CString::new("TraceletRust") {
            if let Ok(c_text) = CString::new(msg) {
                unsafe {
                    __android_log_write(4, c_tag.as_ptr(), c_text.as_ptr()); // 4 = INFO
                }
            }
        }
    }
    #[cfg(not(target_os = "android"))]
    {
        println!("{}", msg);
    }
}

pub fn warn(msg: &str) {
    #[cfg(target_os = "android")]
    {
        if let Ok(c_tag) = CString::new("TraceletRust") {
            if let Ok(c_text) = CString::new(msg) {
                unsafe {
                    __android_log_write(5, c_tag.as_ptr(), c_text.as_ptr()); // 5 = WARN
                }
            }
        }
    }
    #[cfg(not(target_os = "android"))]
    {
        println!("⚠️ {}", msg);
    }
}

pub fn error(msg: &str) {
    #[cfg(target_os = "android")]
    {
        if let Ok(c_tag) = CString::new("TraceletRust") {
            if let Ok(c_text) = CString::new(msg) {
                unsafe {
                    __android_log_write(6, c_tag.as_ptr(), c_text.as_ptr()); // 6 = ERROR
                }
            }
        }
    }
    #[cfg(not(target_os = "android"))]
    {
        eprintln!("❌ {}", msg);
    }
}
