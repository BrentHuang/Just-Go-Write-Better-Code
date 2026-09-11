# unsafe 包与 uintptr 类型

[unsafe](https://pkg.go.dev/unsafe) 包提供了绕过 Go 类型系统安全限制的能力，允许进行底层内存操作。

> [!WARNING]
> 警告：使用 unsafe 包的代码不受 Go 1 兼容性保证，仅在必要时使用（如与 C 代码交互、优化性能关键路径）。

```go
func main() {
 // Sizeof 返回类型占用的字节数（编译时计算）
 fmt.Println(unsafe.Sizeof(int(0))) // 8（在 64 位操作系统上）
 fmt.Println(unsafe.Sizeof(false))  // 1

 // Alignof 返回对齐要求
 fmt.Println(unsafe.Alignof(int(0))) // 8

 // Offsetof 返回结构体字段的偏移量
 type S struct {
  A bool
  B int64
  C bool
 }
 fmt.Println(unsafe.Offsetof(S{}.B)) // 8（由于对齐，A 后面有 7 字节填充）
}
```

 `unsafe.Sizeof`、`unsafe.Alignof`、`unsafe.Offsetof` 的返回类型均为 uintptr，表示字节数（类似于 C 语言中的 size_t）

## unsafe.Sizeof

[func Sizeof(x ArbitraryType) uintptr](https://pkg.go.dev/unsafe#Sizeof) 用于获取变量占用的内存字节大小，这个大小并不包括变量 `x` 可能引用的任何内存区域，即对切片、映射等引用类型，`unsafe.Sizeof` 只计算“引用头”的大小，不包含引用的底层数据大小。参数可以是任何变量。

```go
func main() {
 var b bool = true
 fmt.Println(unsafe.Sizeof(b)) // 1

 var i int = 1
 fmt.Println(unsafe.Sizeof(i)) // 8

 var f32 float32 = 1
 fmt.Println(unsafe.Sizeof(f32)) // 4

 var f64 float64 = 1
 fmt.Println(unsafe.Sizeof(f64)) // 8

 var comp64 complex64 = 1 // 8
 fmt.Println(unsafe.Sizeof(comp64))

 var comp128 complex128 = 1 // 16
 fmt.Println(unsafe.Sizeof(comp128))

 var s string = "hello, 世界"
 fmt.Println(unsafe.Sizeof(s)) // 16 (一个指向字节数组的指针 str + 一个 int 类型的 len)

 var up uintptr
 fmt.Println(unsafe.Sizeof(up)) // 8

 var p *int = &i
 fmt.Println(unsafe.Sizeof(p)) // 8

 var s1 []int = nil
 fmt.Println(unsafe.Sizeof(s1)) // 24  --切片的“引用头“包含 data 指针、len、cap 三个字段

 s2 := []int{1, 2, 3}
 fmt.Println(unsafe.Sizeof(s2)) // 24

 var m map[string]int = nil
 fmt.Println(unsafe.Sizeof(m)) // 8  --映射的”引用头“是一个指针类型

 m1 := map[string]int{"a": 1, "b": 2}
 fmt.Println(unsafe.Sizeof(m1)) // 8
}
```

## unsafe.Alignof

[func Alignof(x ArbitraryType) uintptr](https://pkg.go.dev/unsafe#Alignof) 用于获取一个类型的值在内存分配时需要满足的地址对齐保证（Address Alignment Guarantee）。地址对齐保证是一个整数，表示变量的内存地址必须是该整数的倍数，这有助于 CPU 高效地访问内存。参数可以是任何变量。

在 64 位操作系统上，常见数据类型的地址对齐保证值如下：

| 数据类型 | 地址对齐保证（字节） |
| -- | -- |
| byte、int8、uint8、bool | 1 |
| int16、uint16 | 2 |
| int32、uint32、float32、rune、complex64 | 4，complex64 的整体地址对齐保证与其组成部分 float32 一致 |
| int、int64、uint64、float64、complex128 | 8，complex128 的整体地址对齐保证为 8 字节，其实部和虚部各为一个 float64，已自然满足对齐 |
| string、指针、切片、映射、通道、函数、接口 | 8，这些类型的宽度为一个“机器字”，在 64 位系统上为 8 字节 |
| 数组 | 与其元素类型的地址对齐保证相同，例如，`[3]int8` 的地址对齐保证是 1，`[2]int64` 的地址对齐保证是 8 |

```go
func main() {
 var b bool = true
 fmt.Println(unsafe.Alignof(b)) // 1

 var i int = 1
 fmt.Println(unsafe.Alignof(i)) // 8

 var f32 float32 = 1
 fmt.Println(unsafe.Alignof(f32)) // 4

 var f64 float64 = 1
 fmt.Println(unsafe.Alignof(f64)) // 8

 var comp64 complex64 = 1 // 4，与组成部分的类型 float32 一致
 fmt.Println(unsafe.Alignof(comp64))

 var comp128 complex128 = 1 // 8，与组成部分的类型 float64 一致
 fmt.Println(unsafe.Alignof(comp128))

 var s string = "hello, 世界"
 fmt.Println(unsafe.Alignof(s)) // 8

 var u uintptr
 fmt.Println(unsafe.Alignof(u)) // 8

 var p *int = &i
 fmt.Println(unsafe.Alignof(p)) // 8

 var a1 [3]int8
 fmt.Println(unsafe.Alignof(a1)) // 1

 var a2 [2]int64
 fmt.Println(unsafe.Alignof(a2)) // 8
}
```

结构体的地址对齐保证遵循特定规则，直接影响结构体的内存布局和总大小。

- 结构体本身的地址对齐保证：等于其所有字段中最大的那个地址对齐保证。例如，如果一个结构体包含一个 int8（对齐值为 1）和一个 int64（对齐值为 8），那么该结构体整体的地址对齐保证就为 8
- 结构体大小的计算：结构体的总大小必须是其地址对齐保证的整数倍，编译器可能会在字段之间或结构体末尾添加填充字节以满足此要求

## unsafe.Offsetof

[func Offsetof(x ArbitraryType) uintptr](https://pkg.go.dev/unsafe#Offsetof) 用于获取结构体字段相对于结构体起始地址的字节偏移量，参数只能是结构体字段。

合理的结构体字段排序能有效减少内存浪费，常见优化原则是将地址对齐保证值较大的字段声明在较小的字段之前，即按对齐值从大到小排列。

```go
func main() {
 // 优化前
 type Inefficient struct {
  a bool  // 1 字节 + 7 填充
  b int64 // 8 字节
  c int32 // 4 字节 + 4 填充
 } // 总大小：24 字节

 // 优化后（按地址对齐保证值从大到小声明结构体字段）
 type Efficient struct {
  b int64 // 8 字节
  c int32 // 4 字节
  a bool  // 1 字节 + 3 填充
 } // 总大小：16 字节

 var i Inefficient
 var e Efficient

 fmt.Println(unsafe.Sizeof(i)) // 24
 fmt.Println(unsafe.Sizeof(e)) // 16
 // 如果编译器足够智能，可能重排 Inefficient 结构体的字段顺序，其大小也会被自动优化为 16 字节

 fmt.Printf("%d %d %d\n", unsafe.Offsetof(i.a), unsafe.Offsetof(i.b), unsafe.Offsetof(i.c)) // 0 8 16
 fmt.Printf("%d %d %d\n", unsafe.Offsetof(e.b), unsafe.Offsetof(e.c), unsafe.Offsetof(e.a)) // 0 8 12

 fmt.Printf("%d %d %d\n", unsafe.Sizeof(i.a), unsafe.Sizeof(i.b), unsafe.Sizeof(i.c)) // 1 8 4
 fmt.Printf("%d %d %d\n", unsafe.Sizeof(e.b), unsafe.Sizeof(e.c), unsafe.Sizeof(e.a)) // 8 4 1
}
```

todo <https://github.com/dominikh/go-tools> 结构体 size 分析工具

## unsafe.Pointer

`unsafe.Pointer` 是通用指针类型，可与任意普通指针类型互转，类似于 C 语言中的 `void*` 指针，但必须遵循严格的使用规则。

`unsafe.Pointer` 可与 uintptr 类型互转。在与操作系统底层交互或通过 CGO 调用 C 语言函数时，一些接口需要直接接收用整数表示的内存地址。此时，uintptr 可以作为中介，将 Go 指针转换为整数形式的地址传递给这些接口。

## 与 string 和切片相关的函数

[func String(ptr *byte, len IntegerType) string](https://pkg.go.dev/unsafe#String) 返回一个字符串值，其底层字节序列从 ptr 开始，长度为 len。

[func StringData(str string) *byte](https://pkg.go.dev/unsafe#StringData) 返回指向 str 底层字节序列的指针，返回的字节不能被修改。对于空字符串，返回值未指定，可能为 nil。

[func Slice(ptr *ArbitraryType, len IntegerType) []ArbitraryType](https://pkg.go.dev/unsafe#Slice) 返回一个切片，其底层数组从 ptr 开始，长度和容量均为 len。

[func SliceData(slice []ArbitraryType) *ArbitraryType](https://pkg.go.dev/unsafe#SliceData) 返回参数 slice 的 data 指针，即指向底层数组中该切片的首个元素的指针。对 nil 切片返回 nil 指针。

在 `string` 与 `[]byte` 类型互转时，如果要避免内存分配和拷贝，可以使用这几个函数。

```go
func BytesToStringSafe(b []byte) string {
 if len(b) == 0 {
  return ""
 }

 return unsafe.String(unsafe.SliceData(b), len(b))
}

func StringToBytesSafe(s string) []byte {
 if s == "" {
  return nil
 }

 return unsafe.Slice(unsafe.StringData(s), len(s))
}

func main() {
 b := []byte("hello, 世界")
 s := BytesToStringSafe(b)
 fmt.Println(s)

 b2 := StringToBytesSafe(s)
 fmt.Println(string(b2))
}
```
