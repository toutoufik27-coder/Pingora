use mlua::prelude::*;
use std::fs;
use std::path::Path;

fn walk(dir: &Path, out: &mut Vec<String>) {
    if let Ok(rd) = fs::read_dir(dir) {
        let mut entries: Vec<_> = rd.flatten().collect();
        entries.sort_by_key(|e| e.path());
        for e in entries {
            let p = e.path();
            if p.is_dir() { walk(&p, out); }
            else if p.extension().map(|x| x == "luau" || x == "lua").unwrap_or(false) {
                out.push(p.to_string_lossy().to_string());
            }
        }
    }
}

fn main() -> LuaResult<()> {
    let args: Vec<String> = std::env::args().collect();
    let mode = args.get(1).map(|s| s.as_str()).unwrap_or("check");
    let lua = Lua::new();
    match mode {
        "check" => {
            let mut files = vec![];
            for d in &args[2..] { walk(Path::new(d), &mut files); }
            let mut bad = 0;
            for f in &files {
                let src = fs::read_to_string(f).unwrap();
                if let Err(e) = lua.load(&src).set_name(f.as_str()).into_function() {
                    bad += 1;
                    eprintln!("SYNTAX ERROR {}\n  {}", f, e);
                }
            }
            println!("checked {} files, {} errors", files.len(), bad);
            if bad > 0 { std::process::exit(1); }
        }
        "run" => {
            let g = lua.globals();
            g.set("__readfile", lua.create_function(|_, p: String| Ok(fs::read_to_string(&p).ok()))?)?;
            g.set("__listdir", lua.create_function(|_, p: String| {
                let mut v = vec![];
                if let Ok(rd) = fs::read_dir(&p) { for e in rd.flatten() { v.push(e.file_name().to_string_lossy().to_string()); } }
                v.sort();
                Ok(v)
            })?)?;
            g.set("__isdir", lua.create_function(|_, p: String| Ok(Path::new(&p).is_dir()))?)?;
            g.set("__compile", lua.create_function(|lua, (src, name): (String, String)| {
                lua.load(&src).set_name(name).into_function()
            })?)?;
            let file = &args[2];
            let src = fs::read_to_string(file).unwrap();
            let r = lua.load(&src).set_name(file.as_str()).exec();
            if let Err(e) = r { eprintln!("{}", e); std::process::exit(1); }
        }
        _ => {}
    }
    Ok(())
}
