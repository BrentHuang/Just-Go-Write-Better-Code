# fmt 包

[fmt](https://pkg.go.dev/fmt) 是 Go 标准库中的一个包，实现了类似于 C 语言中 printf 和 scanf 的格式化 I/O 功能。常见函数如下：

- [func Print(a ...any) (n int, err error)](https://pkg.go.dev/fmt#Print) 使用默认格式打印操作数，并将结果写到标准输出。仅在两个相邻操作数都不是字符串时，才会在它们之间添加空格。返回写入的字节数以及遇到的任何写入错误
- [func Printf(format string, a ...any) (n int, err error)](https://pkg.go.dev/fmt#Printf) 按照格式字符串的指示对数据进行格式化，并将结果写到标准输出
- [func Println(a ...any) (n int, err error)](https://pkg.go.dev/fmt#Println) 使用默认格式打印操作数，并将结果写到标准输出。始终在操作数之间添加空格，并在末尾添加换行符
- [func Scan(a ...any) (n int, err error)](https://pkg.go.dev/fmt#Scan) 从标准输入读取文本，并将连续出现的、以空格分隔的值依次存入对应的参数中，换行符也视为空格。返回成功扫描的项数，如果返回的项数少于参数个数则表示有错误发生
- [func Scanf(format string, a ...any) (n int, err error)](https://pkg.go.dev/fmt#Scanf) 从标准输入读取文本，并按照格式字符串的指示，将其中连续出现的、以空格分隔的值依次存入对应的参数中。返回成功扫描的项数，如果返回的项数少于参数个数则表示有错误发生。输入中的换行符必须与格式字符串中的换行符严格匹配。唯一的例外是：占位符 `%c` 始终读取输入中的下一个字符（rune），即便它是空白符（如空格、制表符等）或换行符也不例外
- [func Scanln(a ...any) (n int, err error)](https://pkg.go.dev/fmt#Scanln) 与 `fmt.Scan` 类似，区别在于它遇到换行符即停止扫描，且最后一个参数之后必须紧跟着换行符或 EOF

上述向标准输出写入和从标准输入读取的函数是 goroutine-safe 的，每次调用会原子性地执行，并发协程下的每次 `fmt.Println` 调用输出均完整，不会相互交错。

上述函数的变体如下：

- 将格式化结果以字符串返回，而非写到标准输出，函数名以 `S` 开头：
  - [func Sprint(a ...any) string](https://pkg.go.dev/fmt#Sprint)
  - [func Sprintf(format string, a ...any) string](https://pkg.go.dev/fmt#Sprintf)
  - [func Sprintln(a ...any) string](https://pkg.go.dev/fmt#Sprintln)
- 将格式化结果写到指定的 `io.Writer`，函数名以 `F` 开头：
  - [func Fprint(w io.Writer, a ...any) (n int, err error)](https://pkg.go.dev/fmt#Fprint)
  - [func Fprintf(w io.Writer, format string, a ...any) (n int, err error)](https://pkg.go.dev/fmt#Fprintf)
  - [func Fprintln(w io.Writer, a ...any) (n int, err error)](https://pkg.go.dev/fmt#Fprintln)
- 从指定的 `io.Reader` 或字符串读取，对应 `Fscan` 和 `Sscan` 系列：
  - [func Fscan(r io.Reader, a ...any) (n int, err error)](https://pkg.go.dev/fmt#Fscan) / [Fscanf](https://pkg.go.dev/fmt#Fscanf) / [Fscanln](https://pkg.go.dev/fmt#Fscanln)
  - [func Sscan(str string, a ...any) (n int, err error)](https://pkg.go.dev/fmt#Sscan) / [Sscanf](https://pkg.go.dev/fmt#Sscanf) / [Sscanln](https://pkg.go.dev/fmt#Sscanln)
- 将格式化结果追加到字节切片（Go 1.19+），函数名以 `Append` 开头。与 `Sprint` 系列不同，`Append` 系列不会创建新切片，而是将结果追加到传入的切片之后并返回更新后的切片，适合高性能、需要复用缓冲区（如 `[]byte` 池）的场景：
  - [func Append(b []byte, a ...any) []byte](https://pkg.go.dev/fmt#Append)
  - [func Appendf(b []byte, format string, a ...any) []byte](https://pkg.go.dev/fmt#Appendf)
  - [func Appendln(b []byte, a ...any) []byte](https://pkg.go.dev/fmt#Appendln)
- 根据格式字符串生成并返回一个格式化后的错误：
  - [func Errorf(format string, a ...any) (err error)](https://pkg.go.dev/fmt#Errorf)

## 格式化动词

| verb | 说明 |
| -- | -- |
| `%v` | 以默认格式输出值。结构体只显示字段值，不显示字段名 |
| `%+v` | 结构体显示字段名 + 字段值，非结构体与 %v 相同 |
| `%#v` | 值的 Go 语法表示形式，包含类型信息，可直接用作 Go 代码 |
| `%d` | 十进制整数，无符号整数也用 `%d`，没有 `%u` |
| `%x`, `%X`, `%o`, `%O`, `%b` | 十六进制、八进制、二进制，主要用于整数。`%x` a-f 小写字母，`%X` A-F 大写字母，`%O` 带 `0o` 前缀。`%o`、`%b`、`%x` 或 `%X` 加 `#` 前缀输出带 `0`、`0b`、`0x` 或 `0X` 前缀。没有 `%B` |
| `%f`, `%e`, `%E`, `%g`, `%G` | 十进制浮点数。`%f` 小数形式，`%e`、`%E` 科学记数法，`%g`、`%G` 根据值的大小和精度自动选择 `%f` 或 `%e`（`%G` 使用大写 `E`） |
| `%c` | 输出 byte 或 rune 类型的字符，或 Unicode 码点所表示的字符 |
| `%s` | 字符串 |
| `%q` | 按照 Go 语法进行安全转义后的带双引号的字符串或带单引号的字符 |
| `%T` | 值的类型 |
| `%t` | 布尔值 |
| `%p` | 指针，即变量地址（十六进制，前缀 0x），对切片打印其底层数组的首元素地址 |
| `%w` | 用于 `fmt.Errorf` 中包装错误，仅在 `fmt.Errorf` 的格式字符串中有效 |
| `%%` | 百分号 |
| `%U` | 输出字符的 Unicode 码点，格式为 `U+` 后跟十六进制数字，最多 6 位 |

## %v 示例

`%v` 较为常用，v 表示 value，无需关注具体类型：

```go
type Person struct {
 Name string
 Age  int
}

func main() {
 b := true
 i := 10
 f := 1.2
 s := "hello"
 pointer := &i
 fmt.Printf("bool: %v\n", b)          // bool: true  --等同于 %t
 fmt.Printf("int: %v\n", i)           // int: 10  --等同于 %d
 fmt.Printf("float: %v\n", f)         // float: 1.2  --等同于 %g
 fmt.Printf("string: %v\n", s)        // string: hello  --等同于 %s
 fmt.Printf("pointer: %v\n", pointer) // pointer: 0xc0000140a8  --等同于 %p

 p := Person{"Alice", 30}
 fmt.Printf("%v\n", p)  // {Alice 30}  --只有字段值，没有字段名
 fmt.Printf("%+v\n", p) // {Name:Alice Age:30}  --字段名 + 字段值
 fmt.Printf("%#v\n", p) // main.Person{Name:"Alice", Age:30}  --Go 语法表示
}
```

## %c 示例

```go
func main() {
 var b byte = 65
 var r rune = '中'

 fmt.Printf("%c\n", b)      // A  --字符 'A' 的 Unicode 码点为 65
 fmt.Printf("%c\n", r)      // 中
 fmt.Printf("%c\n", 0x4E2D) // 中  --字符 '中' 的 Unicode 码点为 U+4E2D
}
```

## %T 示例

```go
func main() {
 var a, b, c = true, false, "no!"
 fmt.Printf("type of a: %T, type of b: %T, type of c: %T\n", a, b, c) // type of a: bool, type of b: bool, type of c: string
}
```

## %U 示例

```go
func main() {
 fmt.Printf("%U\n", 'A')  // U+0041  --字符 'A' 的 Unicode 码点为 U+0041
 fmt.Printf("%#U\n", 'A') // U+0041 'A'  --# 前缀在 Unicode 码点后追加空格和带单引号的字符
 fmt.Printf("%U\n", '中')  // U+4E2D --字符 '中' 的 Unicode 码点为 U+4E2D
 fmt.Printf("%U\n", '🎲')  // U+1F3B2  --最多 6 位
}
```

## %q 示例

基本概念：

- 转义：将特殊字符转换为可见的转义序列，如将不可见的换行符转义为可见的 `\n`
- 不转义：让特殊字符保持其原始功能，如换行符真正换行、制表符真正缩进

%q 的作用：确保输出的字符串是合法的 Go 字符串字面量

- 字符串格式化：将字符串用双引号括起来，并转义其中的特殊字符
- 字符格式化：将 byte 或 rune 字符用单引号括起来，并转义特殊字符

```go
func main() {
 userInput := "Hello\tWorld!\n\"Test\""
 fmt.Printf("原始输入：%s\n", userInput) // %s 不转义，\t 表现为缩进、\n 表现为换行
 fmt.Printf("安全输出：%q\n", userInput) // %q 转义，\t 会输出 \t，\n 会输出 \n

 fmt.Printf("%q\n", '\n')            // '\n'
 fmt.Printf("%q\n", '\x07')          // '\a'（bell 字符）
 fmt.Printf("%q\n", 65)              // 'A'  --字符 'A' 的 Unicode 码点为 65
 fmt.Printf("%q\n", 20013)           // '中'  --字符 '中' 的 Unicode 码点为 U+4E2D，十进制是 20013
 fmt.Printf("%q\n", []byte("Hello")) // "Hello"
}

// 原始输入：Hello World!
// "Test"
// 安全输出："Hello\tWorld!\n\"Test\""
```

## %w 示例

```go
func main() {
 err := fmt.Errorf("inner error")
 err = fmt.Errorf("invalid input: %w", err)
 fmt.Println(err)            // invalid input: inner error
 err = fmt.Errorf("%w", err) // 继续包装错误
 fmt.Println(err)            // invalid input: inner error
}
```

## 参数索引

在 `%` 后使用 `[n]` 指定使用第 n 个参数，n 从 1 开始。后续未指定索引的动词会依次使用下一个参数（即 n+1, n+2, ...）。

参数索引能够灵活控制参数顺序，便于重复使用同一个参数。

```go
func main() {
 b := true
 fmt.Printf("%[1]T %[1]v\n", b) // bool true

 fmt.Printf("%[2]d %.2f %[1]s\n", "A", 10, 20.5) // 10 20.50 A
}
```

## 宽度和精度控制

- `%5d`：最小宽度为 5，右对齐，不足补空格
- `%-5d`：最小宽度为 5，左对齐，不足补空格
- `%.2f`：保留 2 位小数
- `%10.2f`：最小宽度 10，右对齐，保留 2 位小数
- `%05d`：最小宽度 5，右对齐，不足补 0
- `%+d`：显示正负号
- `% x`：十六进制表示，整数加前导空格，字节切片在每个字节间插入空格
- `%*.*f`：动态宽度和精度

特别注意：宽度和精度的单位是 Unicode 码点（rune），而非字节（byte），这意味着格式化时统计的“字符个数”是按 Unicode 字符算的。

示例：

```go
func main() {
 // %5d：最小宽度为 5，右对齐（不足补空格）
 fmt.Printf("|%5d|\n", 42)    // |   42|
 fmt.Printf("|%5d|\n", 12345) // |12345|

 // %-5d：最小宽度为 5，左对齐
 fmt.Printf("|%-5d|\n", 42)    // |42   |
 fmt.Printf("|%-5d|\n", 12345) // |12345|

 // %.2f：保留 2 位小数
 fmt.Printf("|%.2f|\n", 3.14159) // |3.14|
 fmt.Printf("|%.2f|\n", 2.0)     // |2.00|

 // %10.2f：最小宽度 10，右对齐，保留 2 位小数
 fmt.Printf("|%10.2f|\n", 3.14)    // |      3.14|
 fmt.Printf("|%10.2f|\n", 123.456) // |    123.46|

 // %05d：最小宽度 5，右对齐，不足补 0
 fmt.Printf("|%05d|\n", 42)  // |00042|
 fmt.Printf("|%05d|\n", 123) // |00123|

 // %+d：显示正负号
 fmt.Printf("|%+d|\n", 42)  // |+42|
 fmt.Printf("|%+d|\n", -42) // |-42|

 // % x 对整数的效果：在十六进制表示前加一个空格
 fmt.Printf("|% x|\n", 255) // | ff|
 fmt.Printf("|%x|\n", 255)  // |ff|

 // % x：对字节切片的效果：在每个字节间插入空格
 data := []byte{0xDE, 0xAD, 0xBE, 0xEF}
 fmt.Printf("|% x|\n", data) // |de ad be ef|
 fmt.Printf("|%x|\n", data)  // |deadbeef|

 // %*.*f：动态宽度和精度（宽度和精度由后续参数提供）
 width := 10
 precision := 2
 value := 3.14159
 fmt.Printf("|%*.*f|\n", width, precision, value) // |      3.14|

 // [2]* 表示宽度由第 2 个参数（8）提供，[1]* 表示精度由第 1 个参数（3）提供，[3] 表示值由第 3 个参数（2.71828）提供
 fmt.Printf("|%[2]*.[1]*[3]f|\n", 3, 8, 2.71828)  // |   2.718|

 // 宽度和精度的单位是 Unicode 码点（rune），而非字节（byte）
 fmt.Printf("|%6s|\n", "hello")  // | hello|
 fmt.Printf("|%6s|\n", "你好")     // |    你好|
 fmt.Printf("|%.2s|\n", "hello") // |he|
 fmt.Printf("|%.2s|\n", "你好")    // |你好|
}
```
