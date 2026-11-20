# Compilar e rodar C/C++ com gcc

_Manual de bolso para consultar quando esquecer um comando_

Todos os comandos deste manual foram executados no Arch Linux (gcc 16.2, gdb 18.1, make 4.4). No macOS o `gcc` é, na verdade, o Clang da Apple: os comandos são os mesmos, exceto onde indicado.

## 1. Início rápido

O mínimo para compilar e rodar um arquivo:

```
gcc main.c -o prog        # compila
./prog                    # roda
```

O comando que recomendo como padrão para estudar:

```
gcc -Wall -Wextra -g main.c -o prog
./prog
```

| Pedaço | Significado |
|---|---|
| `gcc` | chama o compilador de C (`g++` para C++) |
| `-Wall -Wextra` | liga os avisos úteis; é a única flag que realmente pega bugs |
| `-g` | grava nomes e linhas no executável, para o depurador (gdb) mostrar o código |
| `main.c` | arquivo-fonte |
| `-o prog` | nome do executável. Sem `-o` ele se chama `a.out` |
| `./prog` | o `./` é obrigatório: o shell só procura programas nas pastas do PATH, não na pasta atual |

Para C++, troque por `g++` e o arquivo por `.cpp`. Para escolher a versão da linguagem:

```
g++ -Wall -Wextra -g -std=c++20 main.cpp -o prog
```

O gcc 16 já usa C23 por padrão em C, então `-std=` quase nunca é necessário.

> **Por que usar -Wall.** Testei um código com 3 bugs (variável não inicializada, variável sem uso e `%d` com um `long`). Sem flags ele compilou em silêncio e imprimiu lixo. Com `-Wall -Wextra` saíram 3 avisos apontando as linhas.

## 2. Rodar o programa

```
./prog 16 abc            # argumentos (chegam em argc/argv)
echo $?                  # código de saída do último comando
./prog > saida.txt       # grava o que o programa imprime (stdout) num arquivo
./prog 2> erros.txt      # grava só os erros (stderr)
./prog | less            # rola a saída
time ./prog              # mede o tempo de execução
```

| Código de saída | Significa |
|---|---|
| `0` | terminou bem (o `return 0;` do main) |
| `1` a `125` | erro escolhido pelo próprio programa (`return 3;`) |
| `134` | 128 + 6: o programa abortou (`abort()`, falha de `assert`) |
| `139` | 128 + 11: **segmentation fault** (acesso inválido à memória) |

> **Printf some quando o programa trava.** Quando a saída não é um terminal (redirecionada ou em pipe), o `printf` fica em buffer e uma linha impressa logo antes de um crash pode nunca aparecer. Para ver tudo: `fflush(stdout);` depois do `printf`, ou imprimir com `fprintf(stderr, ...)`, que não usa buffer.

## 3. Vários arquivos

Estrutura típica: um `.h` com a **declaração** (o que existe) e um `.c` com a **definição** (o corpo).

```
soma.h     int soma(int a, int b);                         <- declaração
soma.c     #include "soma.h"  int soma(...) { ... }        <- definição
main.c     #include "soma.h"  ... soma(40, 2) ...          <- uso
```

Compilar tudo de uma vez (o jeito mais simples):

```
gcc -Wall -Wextra -g main.c soma.c -o prog -lm
```

Em etapas, que é o que um Makefile faz (só recompila o arquivo que mudou):

```
gcc -Wall -Wextra -g -c main.c        # gera main.o (não linka)
gcc -Wall -Wextra -g -c soma.c        # gera soma.o
gcc main.o soma.o -o prog -lm         # linka os objetos no executável
```

`#include "x.h"` procura primeiro na pasta do arquivo; `#include <x.h>` procura nas pastas do sistema. Para dizer ao compilador outra pasta de headers, use `-I`:

```
gcc -Iinc main.c soma.c -o prog -lm     # procura headers também em ./inc
```

## 4. Flags: o que cada uma faz

| Flag | Para quê |
|---|---|
| `-Wall -Wextra` | avisos úteis. **Use sempre** |
| `-Wpedantic` | avisa o que foge do padrão da linguagem |
| `-Werror` | transforma todo aviso em erro (a compilação falha). Bom para ter disciplina |
| `-g` | informação de depuração (necessária para o gdb) |
| `-O0` | sem otimização (é o padrão). Melhor para depurar |
| `-O2` | otimização forte. Use ao medir desempenho (o gdb mostra menos coisas) |
| `-std=c17`, `-std=c++20` | versão da linguagem |
| `-DNOME` / `-DNOME=valor` | define uma macro, como um `#define` na linha de comando |
| `-Ipasta` | pasta extra de headers |
| `-Lpasta` | pasta extra de bibliotecas |
| `-lnome` | liga a biblioteca `libnome` (ex.: `-lm` liga a matemática) |
| `-c` | só compila (gera `.o`), não linka |
| `-E` / `-S` | para após o pré-processador / após gerar o assembly |
| `-o nome` | nome do arquivo de saída |
| `-save-temps` | guarda os arquivos intermediários (`.i`, `.s`, `.o`) |
| `-v` | mostra os programas que o gcc chama por baixo |
| `-fsanitize=address,undefined` | detecta erro de memória e comportamento indefinido ao rodar (veja a seção 8) |

`-D` na prática:

```
gcc -DDEBUG -DN=5 d.c -o d        # equivale a #define DEBUG e #define N 5 no código
```

## 5. As etapas da compilação e como inspecioná-las

```
gcc -E main.c -o main.i        # 1. pré-processador: #include/#define viram texto
gcc -S main.c                  # 2. compilador: C -> assembly (main.s)
gcc -c main.c                  # 3. montador: assembly -> objeto (main.o)
gcc main.o soma.o -o prog      # 4. linker: objetos + bibliotecas -> executável
```

Ou tudo de uma vez, guardando os intermediários: `gcc -save-temps -c main.c` gera `main.i`, `main.s` e `main.o`.

| Comando | O que mostra |
|---|---|
| `file prog` | tipo do arquivo (ELF 64-bit, dinâmico...) |
| `nm main.o` | símbolos. `T` = definido aqui, `U` = usado mas **indefinido** (o linker resolve) |
| `objdump -d prog --no-show-raw-insn` | o assembly do executável, função por função |
| `readelf -h prog` | cabeçalho do ELF (tipo, ponto de entrada) |
| `ldd prog` | bibliotecas dinâmicas que ele carrega ao rodar |
| `size prog` | tamanho das seções (código, dados) |
| `strings prog` | textos legíveis dentro do binário |

Exemplo real de `nm main.o` (antes do link):

```
0000000000000000 T main
                 U printf
                 U soma
```

## 6. Bibliotecas

### Biblioteca do sistema: -l

```
gcc main.c -o prog -lm          # math.h (sqrt, pow, sin...)
```

Sem o `-lm`, o link falha com `undefined reference to 'sqrt'` (testado). Coloque as bibliotecas **depois** dos arquivos que as usam.

### Biblioteca de terceiros: pkg-config

```
pkg-config --cflags --libs zlib                  # imprime: -lz
gcc z.c -o z $(pkg-config --cflags --libs zlib)  # usa as flags certas
```

### Criar uma biblioteca estática (.a)

```
gcc -c soma.c -o soma.o
ar rcs lib/libsoma.a soma.o                       # empacota
gcc -Iinc main.c -Llib -lsoma -lm -o prog         # usa (o nome é libsoma.a -> -lsoma)
```

### Criar uma biblioteca dinâmica (.so)

```
gcc -fPIC -c soma.c -o soma_pic.o
gcc -shared soma_pic.o -o lib/libsomad.so
gcc -Iinc main.c -Llib -lsomad -lm -o prog
```

Ao rodar, o sistema precisa **achar** a `.so`. Sem isso:

```
./prog: error while loading shared libraries: libsomad.so: cannot open shared object file
```

Duas soluções:

```
LD_LIBRARY_PATH=lib ./prog                                         # só para este comando
gcc ... -Wl,-rpath,'$ORIGIN/lib' -o prog                           # grava o caminho no executável
```

## 7. Makefile mínimo

Crie um arquivo chamado `Makefile`. As linhas de comando começam com **TAB** (não espaços):

```
CC      = gcc
CFLAGS  = -Wall -Wextra -g
LDLIBS  = -lm
OBJS    = main.o soma.o

prog: $(OBJS)
	$(CC) $(OBJS) -o prog $(LDLIBS)

%.o: %.c soma.h
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) prog

.PHONY: clean
```

| Comando | O que faz |
|---|---|
| `make` | compila o que for necessário |
| `make clean` | apaga objetos e executável |
| `make -n` | só mostra o que executaria, sem executar |
| `make -B` | força recompilar tudo |
| `make -j4` | compila 4 arquivos em paralelo |
| `make CC=clang` | troca o compilador só nesta execução |

Comportamento testado: a 2ª vez que você roda `make` sem mudar nada, ele diz `'prog' is up to date`. Ao alterar só o `soma.c`, ele recompila apenas o `soma.o` e refaz o link.

O Makefile acima declara `soma.h` como dependência de todos os `.o`. Em projetos maiores, peça ao gcc que gere as dependências sozinho com `-MMD` (cria `main.d` com `main.o: main.c soma.h`).

## 8. Depurar

### gdb

Compile com `-g` e sem otimização (`-O0`, o padrão), depois:

```
gdb ./prog
```

| Comando no gdb | O que faz |
|---|---|
| `break main` / `break soma` / `break soma.c:2` | põe um ponto de parada |
| `run` / `run 16 abc` | executa (com argumentos) |
| `next` (`n`) | executa a próxima linha, sem entrar nas funções |
| `step` (`s`) | executa a próxima linha, entrando nas funções |
| `continue` (`c`) | segue até o próximo ponto de parada |
| `print x` (`p x`) | mostra o valor de uma variável ou expressão |
| `info locals` | mostra todas as variáveis locais |
| `backtrace` (`bt`) | mostra a pilha de chamadas |
| `finish` | roda até a função atual retornar |
| `watch x` | para quando `x` mudar |
| `list` | mostra o código ao redor |
| `quit` (`q`) | sai |

Sessão real (parou dentro de `soma` e mostrou os argumentos):

```
Breakpoint 1, soma (a=40, b=2) at soma.c:2
#0  soma (a=40, b=2) at soma.c:2
#1  0x00005555555551ba in main (argc=1, argv=0x7fffffffda98) at main.c:7
$1 = 40
$2 = 2
```

Um **segmentation fault** dentro do gdb mostra a linha do erro:

```
(gdb) run
Program received signal SIGSEGV, Segmentation fault.
(gdb) bt
#0  0x000055555555515c in main () at seg.c:2
```

> **Aviso do debuginfod no Arch.** O gdb pergunta se quer baixar símbolos de debug (`Enable debuginfod for this session?`). Para parar de perguntar, crie `~/.gdbinit` com a linha `set debuginfod enabled off`.

### Sanitizers (detectam erros de memória rodando o programa)

```
gcc -g -fsanitize=address,undefined main.c -o prog
./prog
```

Com um `v[3] = 1;` num vetor de 3 posições, o programa normal terminou com saída `0` como se estivesse certo; com `-fsanitize=address` ele parou com `ERROR: AddressSanitizer: heap-buffer-overflow ... WRITE of size 4` e a linha exata.

### valgrind (Linux)

Não está instalado nesta máquina (não testei). Instalação: `sudo pacman -S valgrind`. Uso: `valgrind --leak-check=full ./prog`. Não funciona nas versões atuais do macOS: lá use `-fsanitize=address`.

## 9. Erros comuns e o que significam

| Mensagem | Quem reclamou e por quê |
|---|---|
| `implicit declaration of function 'x'` | **compilador**: usou uma função sem declarar. Falta `#include` ou protótipo |
| `undefined reference to 'x'` | **linker**: ninguém definiu `x`. Falta ligar o `.c`/`.o` com o corpo da função, ou a biblioteca (`-lm`) |
| `fatal error: x.h: No such file or directory` | **pré-processador**: header não encontrado. Nome errado ou falta `-Ipasta` |
| `cannot find -lfoo` | **linker**: biblioteca `libfoo` não encontrada. Falta `-Lpasta` ou instalar o pacote |
| `multiple definition of 'x'` | **linker**: a mesma função definida em dois `.c` (ou o corpo dentro de um header) |
| `expected ';' before ...` | falta um `;` na linha **anterior** à que o gcc aponta (comum) |
| `'x' is used uninitialized` | aviso (`-Wall`): variável lida antes de receber valor |
| `unused variable 'x'` | aviso: variável declarada e nunca usada |
| `format '%d' expects ... 'int'` | aviso: o `printf` usa um formato diferente do tipo do argumento (`%ld` para `long`) |
| `Segmentation fault (core dumped)` | acesso inválido à memória (ponteiro nulo, vetor fora do limite). Use `gdb` ou `-fsanitize=address` |
| `error while loading shared libraries: libx.so` | ao **rodar**: a `.so` não foi achada. Veja `LD_LIBRARY_PATH` e `-rpath` na seção 6 |

Dica: em C, o erro que aparece **primeiro** costuma causar os seguintes. Corrija de cima para baixo e recompile.

## 10. Atalhos no terminal e no nvim

### Função no zsh

Coloque no `~/.zshrc` (testada). Compila todos os `.c` que você passar e roda o resultado:

```
ccr() { gcc -Wall -Wextra -g "$@" -lm && ./a.out; }

ccr main.c               # um arquivo
ccr main.c soma.c        # vários
```

### Dentro do nvim

```
:!gcc -Wall -Wextra -g % -o %:r && ./%:r      " compila e roda o arquivo atual
:!make                                        " roda o make
:make                                         " roda o make e leva os erros ao quickfix (:copen)
:term                                         " abre um terminal dentro do nvim
```

No nvim, `%` é o arquivo atual e `%:r` é o mesmo nome sem a extensão (`main.c` -> `main`).

`K` sobre uma função abre a página de manual dela (`man 3 printf`).

> **Falta instalar as man pages.** Nesta máquina `man 3 printf` e `man malloc` respondem `No manual entry`. Instale com `sudo pacman -S man-pages` e o `K` do nvim passa a funcionar para as funções da libc.

## 11. No macOS (MacBook Apple Silicon)

O `gcc` do macOS é o **Clang da Apple** (`gcc --version` mostra "Apple clang"). Compilar, `-Wall -Wextra -g`, `-fsanitize=address,undefined`, Makefile e `-l/-L/-I` funcionam igual. O que muda:

| No Linux | No macOS (M4) |
|---|---|
| `gdb ./prog` | **`lldb ./prog`** (o gdb não roda bem em Apple Silicon). Comandos: `b main`, `run`, `n`, `s`, `p x`, `bt`, `c`, `q` |
| `ldd prog` | `otool -L prog` |
| `objdump -d prog` | `otool -tV prog` (ou `objdump -d`, que o Clang da Apple também traz) |
| `readelf -h prog` | `otool -hv prog` (o formato é Mach-O, não ELF) |
| `file prog` | igual, mas mostra `Mach-O 64-bit executable arm64` |
| `size prog` | igual |
| `valgrind` | não suportado: use `-fsanitize=address` ou `leaks --atExit -- ./prog` |
| `LD_LIBRARY_PATH` | `DYLD_LIBRARY_PATH` (ou `-Wl,-rpath,@executable_path/lib`) |
| biblioteca dinâmica `.so` | `.dylib`: `gcc -shared -fPIC soma.c -o lib/libsomad.dylib` |
| `man 3 printf` | já vem instalado |
| `Segmentation fault (core dumped)` | `Segmentation fault: 11` (código de saída 139 igual) |

`brew install gcc` instala o GCC de verdade como `gcc-15` (o `gcc` continua sendo o Clang). Só use se precisar comparar.

Depurar um segfault no lldb:

```
lldb ./prog
(lldb) run
(lldb) bt
```

## 12. Resumo de uma página

```
# compilar e rodar
gcc -Wall -Wextra -g main.c -o prog && ./prog
gcc -Wall -Wextra -g main.c soma.c -o prog -lm        # vários arquivos
g++ -Wall -Wextra -g -std=c++20 main.cpp -o prog      # C++

# etapas
gcc -E main.c -o main.i      gcc -S main.c      gcc -c main.c      gcc a.o b.o -o prog

# inspecionar
file prog   nm main.o   objdump -d prog   readelf -h prog   ldd prog   size prog

# bibliotecas
-lm  -Lpasta  -Ipasta        ar rcs libx.a x.o        gcc -shared -fPIC ... -o libx.so

# make
make   make clean   make -n   make -B   make -j4

# depurar
gdb ./prog          (break main, run, next, step, print x, bt, finish, quit)
gcc -g -fsanitize=address,undefined main.c -o prog

# código de saída
echo $?             (0 ok, 139 segfault, 134 abort)
```

### O que ainda falta instalar

| Pacote | Para quê | Arch | macOS |
|---|---|---|---|
| man-pages | `man 3 printf`, `K` no nvim | `sudo pacman -S man-pages` | já vem |
| valgrind | achar vazamento de memória | `sudo pacman -S valgrind` | não suportado; use `-fsanitize=address` |
| clang (opcional) | comparar com o gcc, `clang-tidy` | `sudo pacman -S clang` | já vem (Command Line Tools) |
