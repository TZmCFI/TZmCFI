extern crate clap;
#[macro_use]
extern crate nom;
#[macro_use]
extern crate lazy_static;
extern crate num_integer;
extern crate num_traits;
extern crate unicase;

use std::ffi::OsStr;

mod arm;
mod gasio;
mod utils;

fn main() {
    use clap::{App, Arg};

    let matches = App::new("TZmCFI patcher")
        .author("Tomoaki K.")
        .about("Minimum-viable patching utility to enable inline CFI.")
        .arg(
            Arg::with_name("INPUT")
                .help("The input/output assembler files (.s) to process")
                .long_help(
                    "The assembler files (.s) to process.\n\n\
                     You must specify all the assembler files that comprises \
                     the application here. (i.e., All references therein must \
                     be resolvable.) All the input assembler files are \
                     processed as a whole and will be overwritten with the \
                     output.",
                )
                .multiple(true)
                .index(1),
        )
        .get_matches();

    let files: Vec<&OsStr>;
    if let Some(x) = matches.values_of_os("INPUT") {
        files = x.collect();
    } else {
        println!("No inputs files were given.");
        return; // This is not an error
    }

    for file in files.iter() {
        use std::fs::File;
        use std::io::BufReader;
        println!("  {:?}", file);
        let mut file = File::open(file).unwrap();
        let mut reader = BufReader::new(file);
        let mut parser = gasio::GasParser::new(reader);
        while let Some(x) = parser.next().unwrap() {
            if x.labels.len() > 0 {
                println!("label: {:?}", x.labels);
            }
            if let Some(ref dir) = x.directive {
                let parsed = gasio::arm::ArmGasDirective::from_raw_directive(dir);
                if parsed.is_err() {
                    println!("  directive: {:?}", parsed);
                }
            }
        }
    }

    println!("Not implemented :)");
}
