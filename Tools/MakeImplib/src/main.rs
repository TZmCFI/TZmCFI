use goblin::Object;
use memmap::MmapOptions;
use std::{collections::HashMap, fs::File};

fn main() {
    use clap::{App, Arg};

    let matches = App::new("Make a custom CMSE import library")
        .author("Tomoaki K.")
        .about(".")
        .arg(
            Arg::with_name("INPUT")
                .help("ELF file to load absolute address from")
                .multiple(true)
                .index(1)
                .required(true),
        )
        .arg(
            Arg::with_name("symbol")
                .help("Names of symbols to include")
                .takes_value(true)
                .multiple(true)
                .number_of_values(1)
                .short("s")
                .long("symbol")
                .required(true),
        )
        .get_matches();

    let mut included_symbols: HashMap<&str, Option<u64>> = matches
        .values_of("symbol")
        .unwrap()
        .map(|name| (name, None))
        .collect();

    // Get symbol addresses
    for input in matches.values_of_os("INPUT").unwrap() {
        let file = File::open(input)
            .unwrap_or_else(|x| panic!("failed to open file {:?}: {:?}", input, x));
        let mmap = unsafe { MmapOptions::new().map(&file) }
            .unwrap_or_else(|x| panic!("failed to mmap {:?}: {:?}", input, x));

        let object = Object::parse(&mmap)
            .unwrap_or_else(|x| panic!("failed to parse file {:?}: {:?}", input, x));
        let elf = match &object {
            Object::Elf(elf) => elf,
            _ => panic!("{:?} is not an ELF object file", input),
        };

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

    // Generate an assembler input
    // FIXME: Probably this isn't the right way to create an import library.
    println!(".syntax unified");
    for (name, addr) in &symbols {
        let addr = addr & !1;
        println!(".set {}, 0x{:08x}", name, addr);
        println!(".global {}", name);
    }
}
