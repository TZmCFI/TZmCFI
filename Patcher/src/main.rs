extern crate clap;

fn main() {
    use clap::{App, Arg, SubCommand};

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
                     output.\n\n\
                     This command is designed to be idempotent, i.e., you can \
                     run this command on the same set of inputs as many times as \
                     you like to, and you will get consistent results. To obtain \
                     this property, this command automatically creates the \
                     backup of the input files and tracks their timestamps.",
                )
                .required(true)
                .multiple(true)
                .index(1),
        )
        .get_matches();

    unimplemented!()
}
