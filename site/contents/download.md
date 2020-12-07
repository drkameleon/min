-----
content-type: "page"
title: "Download"
-----
{@ _defs_.md || 0 @}


You can download one of the following pre-built min binaries:

* {#release||{{$version}}||macosx||macOS||x64#}
* {#release||{{$version}}||windows||Windows||x64#}
* {#release||{{$version}}||linux||Linux||x64#}

{#release -> [min v$1 for $3 ($4)](https://github.com/h3rald/min/releases/download/v$1/min\_v$1\_$2\_$4.zip) #}

{{guide-download}}

## Building from Source

Alternatively, you can build min from source in one of the following ways:

### Using nimble

If you already installed [nim](https://nim-lang.org), you probably already have the [nimble](https://github.com/nim-lang/nimble) package manager installed.

If that's the case, simply run **nimble install min**. This will actually install and run [nifty](https://github.com/h3rald/nifty) which will download min dependencies for you before compiling. 

### Without using nimble

1. Download and install [nim](https://nim-lang.org).
2. Download and build [nifty](https://github.com/h3rald/nifty), and put the nifty executable somewhere in your [$PATH](class:kwd).
3. Clone the min [repository](https://github.com/h3rald/min).
4. Navigate to the min repository local folder.
5. Run **nifty install** to download min’s dependencies.
7. Run **nim c -d:release min.nim**.

### Additional build options


#### -d:ssl

If the **-d:ssl** flag is specified when compiling, min will be built with SSL support, so it will be possible to perform HTTPS requests with the {#link-module||http#}. This means that the resulting **min** executable will no longer be self-contained and it will require the OpenSSL dynamic library to be available on your system.

#### -d:lite

If the **d:lite** flag is specified, an even more minimal executable file will be generated, however the following functionalities will not be available:

* The {#link-module||crypto#}
* The {#link-module||net#}
* The {#link-module||http#}
* The {#link-module||math#}
* The {#link-operator||sys||zip#} and {#link-operator||sys||unzip#} operators.

## Running then min Shell

To start min shell, run [min -i](class:cmd). You will be presented with a prompt displaying the path to the current directory:

> %min-terminal%
> [[/Users/h3rald/test]$](class:prompt)

You can type min code and press [ENTER](class:kbd) to evaluate it immediately:

> %min-terminal%
> [[/Users/h3rald/test]$](class:prompt) 2 2 +
>  4 
> [[/Users/h3rald/test]$](class:prompt)

The result of each operation will be placed on top of the stack, and it will be available to subsequent operation

> %min-terminal%
> [[/Users/h3rald/test]$](class:prompt) dup *
>  16
> [[/Users/h3rald/test]$](class:prompt)

To exit min shell, press [CTRL+C](class:kbd) or type [0 exit](class:cmd) and press [ENTER](class:kbd).

> %tip%
> 
> By default, the min shell provides advanced features like tab-completion, history, etc. If however, you run into problems, you can disable these features by running [min -i](class:cmd) instead, and run min shell with a bare-bones REPL. 

## Executing a min Program

To execute a min script, you can:

* Run `min -e:"... program ..."` to execute a program inline.
* Run `min myfile.min` to execute a program contained in a file.

min also supports running programs from standard input, so the following command can also be used (on Unix-like system) to run a program saved in [myfile.min](class:file):

> %min-terminal%
> 
> [$](class:prompt) cat myfile.min | min

## Syntax Highlighting

* If you are using [Visual Studio Code](https://code.visualstudio.com/), you can install the official [min extension](https://marketplace.visualstudio.com/items?itemName=h3rald.vscode-min-lang) which provides syntax highlighting support, code folding, and auto-indentation.
* If you are using [Vim](https://www.vim.org), a [min.vim](https://github.com/h3rald/min/blob/master/min.vim) syntax definition file is available in the min repo.
* If you are using [Sublime Text 3](https://www.sublimetext.com/3), Rafael Carrasco created a min syntax definition file that is available [here](https://github.com/rscarrasco/min-sublime-syntax).
