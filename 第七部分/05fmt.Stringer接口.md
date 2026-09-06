## fmt.Stringer 接口

todo 对照一下官方文档

fmt.Stringer 接口是一个内置接口类型，其中定义了一个 `String() string` 方法，用于返回自定义类型的字符串描述。

```go
type Stringer interface {
    String() string
}
```

当使用 fmt 包中的打印函数（如 Print、Printf、Println、Sprint、Sprintf 等）输出一个值时，如果该值的类型实现了 Stringer 接口，打印函数会自动调用其 `String()` 方法，用返回的字符串来表示该值，而不是使用默认的格式（例如结构体的字段列表或内存地址）。

对于 fmt.Stringer 接口，由于其 `String()` 方法通常是只读的，实现时使用值接收者更为常见。

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

// 输出：
// loopback: 127.0.0.1
// googleDNS: 8.8.8.8
```

避免无限递归：在 `String()` 方法内部不要直接或间接调用当前类型的 fmt 打印函数（如 `fmt.Sprintf("%v", p)`），否则会无限递归。

```go
type Person struct {
 Name string
 Age  int
}

// func (p Person) String() string {
//  return fmt.Sprintf("%v", p) // 无限递归！
// }

func (p Person) String() string {
 return fmt.Sprintf("Person{Name: %s, Age: %d}", p.Name, p.Age) // 逐个字段格式化
}

func main() {
 p := Person{Name: "Hardy", Age: 20}
 fmt.Println(p)
}
```

不要依赖 fmt 默认行为来打印业务数据，显式调用 `.String()` 会更安全。如果需要 JSON 或特定格式，推荐实现 fmt.Formatter 接口进行精细控制。
