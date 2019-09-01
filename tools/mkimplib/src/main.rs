use goblin::Object;
use memmap::MmapOptions;
use std::{collections::HashMap, fs::File, io, path::PathBuf};
use structopt::StructOpt;

/// Makes a custom CMSE import library
#[derive(StructOpt)]
#[structopt(name = "tzmcfi_mkimplib")]
struct Opt {
    /// ELF files to load absolute address from
    #[structopt(parse(from_os_str), required = true)]
    input: Vec<PathBuf>,

    /// Path to the generated assembly file. Defaults to stdout
    #[structopt(short = "o", parse(from_os_str))]
    output: Option<PathBuf>,

    /// Addiitonal names of symbols to include
    #[structopt(short = "s")]
    symbols: Vec<String>,
}

fn main() {
    let opt = Opt::from_args();

    let mut included_symbols: HashMap<&str, Option<u64>> = opt
        .symbols
        .iter()
        .map(|name| (name.as_str(), None))
        .collect();

    // Get symbol addresses
    for input in opt.input.iter() {
        let file = File::open(input)
            .unwrap_or_else(|x| panic!("failed to open file {:?}: {:?}", input, x));
        let mmap = unsafe { MmapOptions::new().map(&file) }
            .unwrap_or_else(|x| panic!("failed to mmap {:?}: {:?}", input, x));

        // The program is short-lived. Just leak `mmap` so that the symbol names
        // newly inserted to `included_symbols` live long enough
        let mmap: &'static _ = Box::leak(Box::new(mmap));

        let object = Object::parse(&mmap)
            .unwrap_or_else(|x| panic!("failed to parse file {:?}: {:?}", input, x));
        let elf = match &object {
            Object::Elf(elf) => elf,
            _ => panic!("{:?} is not an ELF object file", input),
        };

        // Symbols marked using special symbols `__acle_se_*` are automatically
        // included
        const ENTRY_PREFIX: &str = "__acle_se_";
        for sym in elf.syms.iter() {
            let name = elf.strtab.get_unsafe(sym.st_name).unwrap();
            if name.starts_with(ENTRY_PREFIX) {
                let _ = included_symbols.insert(&name[ENTRY_PREFIX.len()..], None);
            }
        }

        for sym in elf.syms.iter() {
            let name = elf.strtab.get_unsafe(sym.st_name).unwrap();

            let addr_cell = included_symbols.get_mut(name);

            if let Some(addr_cell) = addr_cell {
                if addr_cell.is_some() {
                    eprintln!("warning: Symbol '{}' is defined more than once", name);
                }
                *addr_cell = Some(sym.st_value);
                continue;
            }
        }
    }

    if included_symbols.iter().any(|x| x.1.is_none()) {
        for (name, addr) in included_symbols.iter() {
            if addr.is_none() {
                eprintln!("error: Symbol '{}' is not defined", name);
            }
        }
        panic!("Aborting due to undefined symbols");
    }

    let mut symbols: Vec<_> = included_symbols
        .into_iter()
        .map(|(name, addr)| (name, addr.unwrap()))
        .collect();
    symbols.sort_by_key(|(_, addr)| *addr);

    // Open the output stream
    let (mut out_file, mut out_stdout);
    let writer: &mut dyn io::Write;
    let path_display;
    let out_name: &dyn std::fmt::Display;
    if let Some(out_path) = &opt.output {
        let file = std::fs::File::create(out_path)
            .unwrap_or_else(|x| panic!("failed to open file {:?}: {:?}", out_path, x));
        out_file = io::BufWriter::new(file);
        writer = &mut out_file;

        path_display = out_path.display();
        out_name = &path_display;
    } else {
        out_stdout = io::stdout();
        writer = &mut out_stdout;

        out_name = &"-";
    }

    (|| -> Result<(), io::Error> {
        // Generate an assembler input
        // FIXME: Probably this isn't the right way to create an import library.
        writeln!(writer, ".syntax unified")?;
        for (name, addr) in &symbols {
            writeln!(writer, ".type {} function", name)?;
            writeln!(writer, ".set {}, 0x{:08x}", name, addr)?;
            writeln!(writer, ".global {}", name)?;
        }
        Ok(())
    })()
    .unwrap_or_else(|x| panic!("failed to write '{}': {:?}", out_name, x));
}
