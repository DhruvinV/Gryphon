---
layout: tutorialLayout
---
# Contributing

First off, thank you for considering contributing to Gryphon. The project can always use the support of anybody who's willing to help.

Contributions can take many forms: you can share the project with other developers, report bugs (we can't fix what we don't know about!), ask for new features, improve the tutorials, contribute some code, etc. The project aims to provide an open and inclusive space for everybody, which is why it abides to the [contributor covenant](https://www.contributor-covenant.org) and has a [code of conduct](https://github.com/vinivendra/Gryphon/blob/master/CODE_OF_CONDUCT.md).

- [Getting in contact](contributing.html#getting-in-contact)
- [Reporting bugs and requesting features](contributing.html#reporting-bugs-and-requesting-features)
- [Improving the website and tutorials](contributing.html#improving-the-website-and-tutorials)
- [Contributing code](contributing.html#contributing-code)
	- [Setting up the environment on macOS](contributing.html#setting-up-the-environment-on-macos)
	- [Setting up the environment on Linux and Docker](contributing.html#setting-up-the-environment-on-linux-and-docker)
	- [Running the tests](contributing.html#running-the-tests)
		- [Unit tests](contributing.html#unit-tests)
		- [Bootstrapping test](contributing.html#bootstrapping-test)
		- [Acceptance and Performance tests](contributing.html#acceptance-and-performance-tests)
		- [Additional Docker tests](contributing.html#additional-docker-tests)
	- [Style](contributing.html#style)
- [How Gryphon works](contributing.html#how-gryphon-works)

## Getting in contact

If at any point you need help using or contributing to Gryphon, or just want to contact the maintainers, feel free to send a message [on Twitter](https://twitter.com/gryphonblog) or [via email](mailto:gryphontranspiler@gmail.com).

## Reporting bugs and requesting features

Reporting bugs and requesting features are very important parts of contributing to any open source project. Many times, a bug hasn't been fixed yet simply because the maintainers do not know it exists. Similarly, a feature may not have been added because the maintainers do not know anyone wants it. Gryphon uses [GitHub issues](https://github.com/vinivendra/Gryphon/issues) to keep track of both bugs and feature requests. Anyone is welcome to open new issues, so long as they are respectful and follow the [code of conduct](https://github.com/vinivendra/Gryphon/blob/master/CODE_OF_CONDUCT.md). If you open a new issue, be sure to tag it with the `bug` label if it's a bug report, or `enhancement` if it's a feature request.

New GitHub issues should be created only for suggesting and discussing ways to improve Gryphon; if you have questions about using Gryphon or need some technical support, try sending a message [on Twitter](https://twitter.com/gryphonblog) or [via email](mailto:gryphontranspiler@gmail.com) instead.

If you find a problem that you think shouldn't be public (for instance, a security issue that someone might exploit if they knew it existed), please *do not* open an issue; just send an email [directly to the maintainers](mailto:gryphontranspiler@gmail.com).

## Improving the website and tutorials

This website is currently hosted using GitHub pages, so its texts and its code are open for anyone who wants to improve them. If you'd like to report a problem, try [sending a message](contributing.html#getting-in-contact) or opening [an issue on GitHub](https://github.com/vinivendra/Gryphon/issues/new).

If you'd like to improve things yourself, feel free to open a pull request - the website is in the `gh-pages` branch, and it's made using [Jekyll](https://jekyllrb.com/docs/). If you don't yet know what a pull request is, keep reading.

## Contributing code

Contributions to the project's website and its code are very much encouraged. Gryphon is a large program that takes a lot of work to maintain and improve, and help is always appreciated.

If this is your first time contributing to an open source project (or contributing to Gryphon), then welcome! Here are a few tips to get you started:
- Gryphon accepts code contributions in the form of a *pull request*. Try reading [this tutorial](http://www.firsttimersonly.com/) or [this one](http://makeapullrequest.com/) to learn more about how pull requests work and how to create your own. Once you do, come back and read the rest of this document to learn how to set up Gryphon's development environment on your computer.
- If don't yet know what kind of improvement you want to make, look for issues labeled [first timers only](https://github.com/vinivendra/Gryphon/labels/first-timers-only). These issues are easier than most, and there will be a maintainer willing to hold your hand to help you get to your first accepted pull request on an open source project. If there aren't any of these open, you can [send a message](contributing.html#getting-in-contact) asking for one. If you're feeling confident, you can also try out [good first issues](https://github.com/vinivendra/Gryphon/labels/good%20first%20issue), which are meant for people who have contributed to other projects but are new to Gryphon.
- Remember that everyone was a beginner at first! There's no shame in [asking for help](contributing.html#getting-in-contact).

If you would like to contribute a pull request that isn't yet related to an existing issue, start by [creating an issue of your own](https://github.com/vinivendra/Gryphon/issues/new). It's be a good way to talk about your proposed changes before you start doing the work, and may avoid your pull request being rejected if your changes don't align with the project's direction.

When interacting with the maintainers on GitHub, you can usually expect a response within a couple of days. If you haven’t heard anything after a week, feel free to ping the thread.

Since the public release of the preview (version 0.5), Gryphon uses the `master` branch as its (reasonably) stable branch. This what users will access when installing Gryphon for the first time. Day-to-day development is done on the `development` branch, which is also where pull requests should be made. The `development` branch is merged onto `master` regularly, on a sort-of-weekly basis, resulting in sort-of-weekly updates for the users. The `gh-pages` branch contains the code for this website. Any other branches are works-in-progress that will eventually merge into one of these three main branches.

### Setting up the environment on macOS

Start by cloning the repository:

```` bash
$ git clone https://github.com/vinivendra/Gryphon.git --branch development
$ cd Gryphon
````

Gryphon is set up as a Swift package, so the Swift compiler can be used to generate an Xcode project for navigating the code:

```` bash
$ swift package generate-xcodeproj
$ open Gryphon.xcodeproj
````

Once the Xcode project is open, start by setting it to run in the current directory:

1. Hit **⌘+⇧+,** to open the scheme editor;
2. Select `Run` on the left-hand side, then `Options` on the top;
3. Scroll down to `Working Directory` and check `Use custom working directory`;
4. Set it to `$SRCROOT`, which is the Xcode project's directory.
    ![The working directory option in Xcode's scheme editor](assets/images/contributing/contributing1.png)

Next, set a few arguments to use with the Gryphon executable:

1. Select `Arguments` on the top;
2. Add `test.swift` and `--write-to-console`
3. You might also want to add `-emit-swiftAST -emit-rawAST -emit-AST -emit-kotlin` to print the intermediate representations, which can help debugging.
    ![The arguments section in Xcode's scheme editor](assets/images/contributing/contributing2.png)
4. Close the scheme editor.

These arguments will make Gryphon translate the `test.swift` file in the current directory. You can add this file to the project so that you can change it and use it to test your contributions:

1. Hit **⌘+⌥+A** to open the file selector;
2. Select the `test.swift` file;
3. Uncheck `Gryphon` in the `Add to targets:` section below;
4. Click `Add`.
    ![Xcode file selector window.](assets/images/contributing/contributing3.png)

Once all of that is configured, make sure the `Gryphon` scheme is set to run on `My Mac`, then hit **⌘+R** to run Gryphon.

![Xcode's Gryphon target set to run on the My Mac device.](assets/images/contributing/contributing4.png)

You should see the Kotlin translation of the `test.swift` file show up in Xcode's console, along with other intermediate ASTs if you added the extra arguments.

### Setting up the environment on Linux and Docker

Since Linux and Docker don't have access to Xcode, the setup is pretty much the same for both. Start by cloning the repository if you haven't done it yet:

```` bash
$ git clone https://github.com/vinivendra/Gryphon.git --branch development
$ cd Gryphon
````

Gryphon is set up as a Swift package, so most commands can be called using the Swift package manager. To build the main executable, run:

```` bash
$ swift build
````

Then execute it using:

```` bash
$ ./.build/<my_linux_identifier>/debug/Gryphon
````

Where `<my_linux_identifier>` is the name of a folder that can vary depending on your operating system (but it's usually the only folder available).

A common invocation involves translating the `test.swift` file and printing its intermediate ASTs for debugging:

```` bash
$ ./.build/<my_linux_identifier>/debug/Gryphon test.swift --write-to-console -emit-swiftAST -emit-rawAST -emit-AST -emit-kotlin
````

You can run automated tests on Gryphon (described below) using the following command:

```` bash
$ swift test
````

To run a specific test, use the `--filter` option followed by a regular expression that matches the desired test:

```` bash
$ swift test --filter IntegrationTest
````

## Running the tests

### Setup

The automated tests require Gryphon to be initialized in the current folder. To do that, run:

```` bash
$ swift build
$ ./.build/<my_os_identifier>/debug/Gryphon clean init -xcode
````

On macOS, Gryphon tests support for different Swift versions using available toolchains. Currently, it supports Swift 5.1 and 5.2. This will happen automatically if you have the toolchains installed. You can check their availability with:

```` bash
$ xcrun swift --version
Apple Swift version 5.2.2...

$ xcrun --toolchain "swift 5.1" swift --version
Apple Swift version 5.1...
````

If they're not available, you can download them on [swift.org](https://swift.org/download/#releases) under `Releases > Swift 5.x`.

If the toolchains aren't installed a few tests will fail as a warning that a Swift version isn't being tested, but that is to be expected. Using toolchains to test different Swift versions is recommended but not required for contributing code.

### Unit tests

The Gryphon project contains several test classes. However, not all of them are meant to be executed every time - some have specific purposes, and some take too long. These tests can be removed from the normal unit tests suite to keep it fast so that it can be used often. They will be explained in the following sections.

#### On macOS:

1. On Xcode, hit **⌘+⇧+,** to bring up the scheme editor:
2. Select `Test` on the left-hand side, then `Info` on the top;
3. Click the small triangle on the left of `GryphonLibTests` to open the test list;
4. Uncheck the `AcceptanceTest`, the `BootstrappingTest` and the `PerformanceTest`;
5. Click close, then hit `**⌘+U**` to run the test suite.


#### On Linux and Docker:

1. Open the `Tests/GryphonLibTests/XCTestManifests.swift` file;
2. Make sure the `AcceptanceTest` and the `BootstrappingTest` are commented;
3. Run `swift test` on the terminal to execute the test suite.

### Bootstrapping test

The bootstrapping tests are a way of testing Gryphon with more complicated code than the files in the `Test cases` folder. It consists of making Gryphon translate its own source code into Kotlin, then compiling the result and comparing it to the original Swift executable. This includes seeing if the Kotlin version produces the same output files for each test case, and checking that it passes the same unit tests.

![A diagram illustrating the bootstrapping tests](assets/images/contributing/bootstrapTest.png)

The `prepareForBootstrapTests.sh` script is responsible for translating Gryphon's source code, compiling the translated code, and calling the translated executable to generate the necessary output files for comparison. It should be run before every execution of `BootstrappingTest`, since these tests need updated output files to work.

```` bash
$ bash prepareForBootstrapTests.sh
````

Once the script finishes:
- On macOS, open Xcode, hit **⌘+6** to open the tests navigator, right-click the `BootstrappingTest` and select `Run "BootstrappingTest"`.
- On Linux and Docker, uncomment the `BootstrappingTest` from the `XCTestManifests.swift` file, the run `swift test --filter Bootstrap`.

If any files were out of date (for instance, because the `prepareForBootstrapTests.sh` script wasn't executed), this test will raise an error.

Because the script takes a long time to finish, this test is typically only run before committing changes.

If the test starts raising unexpected errors, try resetting the environment:

1. Run `gryphon clean init -xcode`;
2. Run the unit tests, which will update the test cases;
3. Run `bash prepareForBootstrapTests.sh`;
4. Run only the `BootstrappingTest`.

### Acceptance and Performance tests

These two test classes should only be executed in specific situations.

Acceptance tests are used for making sure that the Kotlin translations of the Swift test cases in the `Test cases` folder work as expected. This is done by compiling the test cases, running them and checking if they produce the expected output (as recorded in the `.output` files). Run them whenever a `.kt` file in the `Test cases` folder is changed.

Performance tests are used only when working on a feature that may significantly impact performance. Run them before making your changes to get a baseline for you computer, then run them after the changes for comparison.

### Additional Docker tests

If you are using macOS, it is recommended to also run the tests in a Docker container to make sure they work on Linux. To do that, follow the instructions on [setting up the Docker container](installingGryphon.html#on-docker), then run any appropriate tests using the "on Linux and Docker" instructions above.

## Style

This project uses SwiftLint, a tool that automatically analyzes the code and sets it to the project's style standards. SwiftLint can be installed using [homebrew](https://brew.sh), or with other methods described in the [project's home page](https://github.com/realm/SwiftLint):

```` bash
$ brew install swiftlint
````

It can be used from the command line to automatically format all Swift source files according to the project's standard. Just run this command from the root directory of the repository:

```` bash
$ swiftlint autocorrect
````

Alternatively, you can run this command automatically with Xcode by adding it as a new Run Script Phase.

## How Gryphon works

This section gives a brief explanation on Gryphon's architecture, in the hopes of making it easier for contributors to understand it and start making changes.

Gryphon is almost entirely implemented as a library, `GryphonLib`. The `gryphon` executable consists of a `main.swift` file that imports this library and redirects the command-line arguments to it, printing errors if there are any.

The entry point for `GryphonLib` is the `Driver` class. This class is responsible for parsing the arguments and calling other classes to do the actual compilation work. The compilation is performed as a pipeline:

![Gryphon's architecture](assets/images/contributing/architecture.png)

First, the `Driver` calls the Swift compiler to turn the Swift files into Swift AST dump files. Then, it calls Gryphon's `Compiler` class to perform the rest of the compilation. The `Compiler` internally delegates to other classes:

- the `ASTDumpDecoder` class *parses* the input test into a `SwiftAST`;
- the `SwiftTranslator` *converts* it to a workable "raw" Swift-like `GryphonAST`;
- the `TranspilationPass` *runs passes* on it, turning it into a "processed" Kotlin-like `GryphonAST`;
- and the `KotlinTranslator` *writes* it into Kotlin code.

Each of these steps receives its input along with other relevant information, most of which is stored in a `TranspilationContext`. They mostly deal with ASTs, or [Abstract Syntax Trees](https://en.wikipedia.org/wiki/Abstract_syntax_tree), a data structure that's very useful for representing code.

The compilation process starts with a Swift AST dump file. This is done because the AST dump is the only format emitted by the Swift compiler that contains all of the information needed by Gryphon to perform the translations. This is unfortunate because the AST dump is intended only for debugging the Swift compiler, and is not stable or even guaranteed to always exist. However, Gryphon needs the type information it provides for crucial parts of its translation process.

In simple cases, the AST dump is obtained by compiling the input files with `swiftc -dump-ast -output-file-map <output file map.json> <swift input files>`. The output file map is a JSON file that says where the AST dump for each input file should be written to. When using Xcode and iOS, this command gets significantly more complicated, and Gryphon tries to adapt Xcode's own swift compilation command to get the AST dumps.

Much of this process is done using files in the `.gryphon` folder. This folder is created whenever the user calls `gryphon init <xcode project>`. It is also created when calling `gryphon <input files>`, then deleted once the translation is done. It can be deleted with `gryphon clean`. This folder is used for containing any auxiliary files that Gryphon might need. This includes the output file map used for dumping Swift's ASTs, the Swift templates used for translating references to the standard library, scripts for dealing with Xcode projects and for mapping Kotlin errors to Swift, and several others.

The `AuxiliaryFileContents.swift` file contains the contents of these files. It also contains the contents of  the `GryphonSwiftLibrary.swift` and the `GryphonKotlinLibrary.kt` files that users add to their projects using `gryphon generate-libraries`. The contents of the library files should always match the strings in this file; there is a test in `DriverTest` that ensures this.

Most of the actual translation work happens in the several `TranspilationPass` classes. Each of these classes is responsible for performing a small part of the translation. There are many of them, as illustrated below, but they change often, so the image is probably already inaccurate.

![A (dated) diagram of 38 Transpilation Passes](assets/images/contributing/passes.png)

Most of Gryphon's compilation is done in parallel for each input file. There is only one necessary point of synchronization, which is in the middle of the transpilation passes (specifically, the dotted line in the first column of the image above). This synchronization point is necessary because some transpilation passes need information from other files, which might not yet be available if the files are in threads that haven't been processed yet. The first few transpilation passes are responsible for recording this information on the shared `TranspilationContext` class. Once that has been done for all files, then the other transpilation passes can continue to work in each file in parallel again.

The `LibraryTranspilationPass.swift` file contains transpilation passes responsible for recording and applying [templates](templates.html) to the source files. These transpilation passes are larger than the others, so they're placed in a separate file so they don't clutter the main `TranspilationPass` file.

After all the transpilation passes have been executed, the resulting `GryphonAST` is handed to the  `KotlinTranslator` class. This class turns the `GryphonAST` into a `KotlinTranslationResult`. A `KotlinTranslationResult` is a finished Kotlin translation - all the strings are there, in the order thay'll be placed in the output file - but it still is structured as an AST. This allows the compiler to create error maps for each file before synthesizing the final code. Error maps are files that map each element in a Kotlin source file to the element in a Swift source file that originated it. Gryphon uses these maps to report Kotlin errors in their corresponding locations in the Swift source files.
