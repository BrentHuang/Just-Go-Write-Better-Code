# fmt.Stringer 接口

[fmt.Stringer](https://pkg.go.dev/fmt#Stringer) 接口定义如下：

```go
type Stringer interface {
    String() string
}
```

其中声明了一个 `String() string` 方法，用于返回自定义类型的字符串形式。

当使用 `fmt` 包中的打印函数（如 `Print`、`Printf`、`Println`、`Sprint`、`Sprintf` 等）输出一个值时，如果该值的类型实现了 `fmt.Stringer` 接口，打印函数会自动调用其 `String() string` 方法，用返回的字符串来表示该值，而不是使用默认格式。

由于 `String() string` 方法通常是只读的，实现时使用值接收者更为常见。

```go
// 让 IPAddr 类型实现 fmt.Stringer 接口，从而能够以点分十进制格式输出 IP 地址
type IPAddr [4]byte

func (ip IPAddr) String() string { // 使用值接收者
 return fmt.Sprintf("%v.%v.%v.%v", ip[0], ip[1], ip[2], ip[3])
}

func main() {
 hosts := map[string]IPAddr{
  "loopback":  {127, 0, 0, 1},
  "googleDNS": {8, 8, 8, 8},
 }
 for name, ip := range hosts {
  fmt.Printf("%v: %v\n", name, ip)
 }
}

// loopback: 127.0.0.1  --如果没有实现 fmt.Stringer 接口，会使用默认格式 [127 0 0 1]
// googleDNS: 8.8.8.8  --实现了 fmt.Stringer 接口，会使用自定义格式 [8 8 8 8]
```

避免无限递归：在 `String() string` 方法内部不要直接或间接调用当前类型的 `fmt` 打印函数（如 `fmt.Sprintf("%v", p)`），否则会无限递归。

```go
type Person struct {
 Name string
 Age  int
}

// func (p Person) String() string {
//  return fmt.Sprintf("%v", p) // 无限递归！  --Sprintf 打印 p，会自动调用 Person 类型的 String() 方法，导致无限递归
// }

func (p Person) String() string {
 return fmt.Sprintf("Person{Name: %s, Age: %d}", p.Name, p.Age) // 逐个字段格式化
}

func main() {
 p := Person{Name: "Alice", Age: 20}
 fmt.Println(p) // Person{Name: Alice, Age: 20}  --如果没有实现 fmt.Stringer 接口，会使用默认格式 {Alice 20}
}
```

打印业务数据时，应确保类型实现了 `fmt.Stringer`，避免依赖 `fmt` 对复合类型的默认结构格式。若需要按不同动词、宽度、精度精细控制打印格式，可进一步实现 `fmt.Formatter` 接口。

## fmt.Formatter 接口

`fmt.Stringer` 的 `String() string` 方法只能返回一个固定的字符串，它无法感知你用了什么动词。比如，你希望 `%v` 输出简洁格式，而 `%+v` 输出带字段名的调试格式，`String() string` 对此无能为力。

[fmt.Formatter](https://pkg.go.dev/fmt#Formatter) 接口定义如下：

```go
type Formatter interface {
 Format(f State, verb rune)
}
```

其中声明了一个 `Format(f State, verb rune)` 方法，用于控制自定义类型的格式化输出，允许针对不同的格式化动词以及宽度、精度、标志位做出不同响应。

参数：

- `f State`：提供格式化上下文，包含：
  - `Write(b []byte) (n int, err error)` 实际写入输出的方法（必须调用，否则什么都不输出）
  - `Width() (wid int, ok bool) / Precision() (prec int, ok bool)` 宽度与精度（对应 `%5d`、`%.2f` 中的 5 和 2）
  - `Flag(c int) bool` 标志位是否开启（如 `'+'`、`'-'`、`'#'`）
- `verb rune`：本次调用使用的格式化动词，如 `'v'`、`'d'`、`'s'`、`'x'`

可以通过 `f.Flag('+')` 判断是否用了 `+` 号（如 `%+v`），通过 `f.Width()` 和 `f.Precision()` 获取宽度和精度，然后使用 `f.Write()` 写入最终内容。

```go
type Point struct{ X, Y int }

// 用无方法的新类型做兜底，避免递归
type point Point

func (p Point) Format(f fmt.State, verb rune) {
 switch verb {
 case 'v':
  if f.Flag('+') { // %+v
   fmt.Fprintf(f, "Point{X=%d, Y=%d}", p.X, p.Y)
  } else { // %v
   fmt.Fprintf(f, "Point{%d, %d}", p.X, p.Y)
  }
 case 'd':
  fmt.Fprintf(f, "距离=%d", p.X+p.Y)
 default: // 兜底：转成不实现 Formatter 的类型再交给 fmt
  fmt.Fprintf(f, "%"+string(verb), point(p))
 }
}

func main() {
 p := Point{3, 4}
 fmt.Printf("%v\n", p)  // Point{3, 4}
 fmt.Printf("%+v\n", p) // Point{X=3, Y=4}
 fmt.Printf("%d\n", p)  // 距离=7
 fmt.Printf("%a\n", p)  // {%!a(int=3) %!a(int=4)}
}
```

几个注意点：

1. 必须真正写出内容：`Format()` 里不调用 `f.Write()` 或 `fmt.Fprintf(f, ...)`，输出就是空的
2. 小心无限递归：在 `Format()` 内对 `p` 本身再用 `%v` 会再次调用 `Format()`。兜底写法是定义一个同底层类型的新类型（如上面的 `type point Point`），它不实现 `Formatter` 接口，交给默认格式化逻辑处理
3. 宽度与精度需手动处理：`f.Write()` 不会自动应用宽度和精度。如果你用了 `%10s`，需要自己根据 `f.Width()` 计算并填充空格，或者委托给 `fmt.Fprintf` 处理（但要小心递归问题）
4. 与 `Stringer` 的区别：`String()` 方法只在 `%v`（非 `%#v`）、`%s`、`%q`、`%x`、`%X` 等动词下触发，且拿不到 `verb` 和标志位；`Format()` 能区分动词、读取宽度/精度/标志，是更底层的完全控制手段。两者同时实现时，`Format()` 的优先级更高。另外，若类型同时实现了 `error` 接口，打印时会优先调用 `Error()` 而非 `String()`。`Error()` 只有在未实现 `Formatter`、且非 `%#v`、且动词属于 `v/s/q/x/X` 时才会被调用
5. `%#v` 与 `GoStringer`：`Formatter` 的优先级最高，即使使用 `%#v`，只要实现了 `Formatter`，fmt 仍会调用 `Format()`。只有当类型未实现 `Formatter`、但实现了 `GoStringer` 接口时，`%#v` 才会调用 `GoString()`。如果即没有实现 `Formatter`、也没有实现 `GoStringer` 时，`%#v` 直接落到默认反射格式化

```go
type MyError struct {
 Code int
 Msg  string
}

// 实现 error 接口
func (e MyError) Error() string {
 return fmt.Sprintf("Error[%d]: %s", e.Code, e.Msg)
}

// 实现 fmt.Stringer 接口
func (e MyError) String() string {
 return fmt.Sprintf("Stringer[%d]: %s", e.Code, e.Msg)
}

func main() {
 e := MyError{Code: 404, Msg: "not found"}

 fmt.Printf("%v\n", e)  // Error[404]: not found
 fmt.Printf("%s\n", e)  // Error[404]: not found
 fmt.Printf("%q\n", e)  // "Error[404]: not found"
 fmt.Printf("%x\n", e)  // 4572726f725b3430345d3a206e6f7420666f756e64  --Error() 返回值的十六进制
 fmt.Printf("%#v\n", e) // main.MyError{Code:404, Msg:"not found"}  --%#v 不走 Error/Stringer
}
```

fmt 的接口匹配优先级（源码：`${GOROOT}/src/fmt/print.go`）:

```text
1. Formatter.Format()          ← 始终检查，所有动词
2. GoStringer.GoString()       ← 仅 %#v
3. error.Error()               ← 动词 v/s/q/x/X 且非 %#v
4. Stringer.String()           ← 动词 v/s/q/x/X 且非 %#v
5. 默认反射格式化
```
