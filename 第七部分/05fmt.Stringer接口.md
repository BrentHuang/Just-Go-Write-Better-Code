# fmt.Stringer 接口

[fmt.Stringer](https://pkg.go.dev/fmt#Stringer) 接口定义如下：

```go
type Stringer interface {
    String() string
}
```

其中声明了一个 `String() string` 方法，用于返回自定义类型的字符串形式。

当使用 fmt 包中的打印函数（如 Print、Printf、Println、Sprint、Sprintf 等）输出一个值时，如果该值的类型实现了 fmt.Stringer 接口，打印函数会自动调用其 `String() string` 方法，用返回的字符串来表示该值，而不是使用默认格式。

由于 `String() string` 方法通常是只读的，实现时使用值接收者更为常见。

```go
// 让 IPAddr 类型实现 fmt.Stringer 接口，从而能够以点阵格式输出 IP 地址
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

避免无限递归：在 `String() string` 方法内部不要直接或间接调用当前类型的 fmt 打印函数（如 `fmt.Sprintf("%v", p)`），否则会无限递归。

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

不要依赖 fmt 默认行为来打印业务数据，显式调用 `.String()` 会更安全。如果需要 JSON 或特定格式，推荐实现 fmt.Formatter 接口进行精细控制。

## fmt.Formatter 接口

fmt.Stringer 的 `String() string` 方法只能返回一个固定的字符串，它无法感知你用了什么动词。比如，你希望 `%v` 输出简洁格式，而 `%+v` 输出带字段名的调试格式，`String() string` 对此无能为力。

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

// 用无方法的内嵌类型做兜底，避免递归
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
4. 与 `Stringer` 的区别：`Stringer`的`String() string` 方法只能被 `%v`、`%s` 等少量动词触发，且拿不到 verb 和标志位；`Formatter` 能区分动词、读取宽度/精度/标志，是更底层的完全控制手段。两者同时实现时，`Formatter` 优先级更高
5. `%#v` 的优先级：如果只实现了 `Formatter` 接口，`%#v` 默认不会调用你的 `Format()` 方法，因为 `%#v` 优先查找 `GoStringer` 接口。如果你想完全控制 `%#v` 的输出，需要同时实现 `GoStringer` 接口
