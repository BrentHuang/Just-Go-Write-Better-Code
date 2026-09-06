## new() 函数

内置函数 [func new(TypeOrExpr) *Type](https://pkg.go.dev/builtin#new) 分配一个新的已初始化变量，并返回指向它的指针。它接受一个参数，该参数可以是类型或表达式。如果参数是类型 T，`new(T)` 分配一个类型为 T 的变量，并初始化为其零值。如果参数是表达式 x，`new(x)` 分配一个类型与 x 相同的变量，并初始化表达式 x 的值。如果表达式 x 的结果是一个无类型常量，那么该常量会先被隐式转换为相应的默认类型。

```go
type Shape interface {
 Area() float64
}

type Circle struct {
 Radius float64
}

func (c *Circle) Area() float64 {
 return 3.14 * c.Radius * c.Radius
}

func main() {
 // 为 int 类型分配内存，初始值为 0
 p1 := new(int) // new 返回 *int 类型的指针变量
 fmt.Printf("%p\n", p1)
 fmt.Printf("%d\n", *p1) // 0 (int 的零值)

 p2 := new(int)
 fmt.Printf("%p\n", p2)  // 与 p1 的地址不同。每次 new 都创建一个新的变量
 fmt.Printf("%d\n", *p2) // 0 (int 的零值)

 // 为自定义结构体分配内存，结构体的各个字段初始化为其类型的零值
 type Person struct {
  Name string
  Age  int
 }
 personPtr1 := new(Person)
 fmt.Printf("%p\n", personPtr1)
 fmt.Printf("%q\n", personPtr1.Name) // "" (string 的零值)
 fmt.Printf("%d\n", personPtr1.Age)  // 0 (int 的零值)

 personPtr2 := new(Person)
 fmt.Printf("%p\n", personPtr2)      // 与 personPtr1 的地址不同
 fmt.Printf("%q\n", personPtr2.Name) // "" (string 的零值)
 fmt.Printf("%d\n", personPtr2.Age)  // 0 (int 的零值)

 // 为长度为 5 的 int 数组分配内存，返回指向数组的指针
 arrPtr := new([5]int)
 for i := range 5 {
  arrPtr[i] = i * 2 // 通过指针操作数组元素
 }
 fmt.Printf("%v\n", *arrPtr) // [0 2 4 6 8]

 // 当某个结构体指针实现了特定接口时，可以使用 new 来创建该结构体的实例，并将其赋值给接口变量
 // 使用 new 创建 Circle 实例（指针）
 circlePtr := new(Circle)
 fmt.Printf("%p\n", circlePtr)
 fmt.Printf("%v\n", *circlePtr) // {0}
 circlePtr.Radius = 5
 var shape = circlePtr // Circle 的指针实现了 Shape 接口
 fmt.Printf("圆的面积：%.2f\n", shape.Area())

 // 对于切片，new 返回一个指向 nil 切片的指针，该切片本身需要使用 make 初始化
 slicePtr := new([]int) // slicePtr 的类型是 *[]int, 值为 nil
 if *slicePtr == nil {  // true
  fmt.Println("nil")
 }
 *slicePtr = make([]int, 5) // 需要额外使用 make 初始化底层数组
 if *slicePtr != nil {      // true
  fmt.Printf("%v\n", *slicePtr) // [0 0 0 0 0]
 }

 p := new(20) // Go 1.26 新增，返回指向 20 的指针 *int
 fmt.Printf("%p\n", p)
 fmt.Printf("%T, %d\n", p, *p) // *int, 20
}
```

---

对于结构体，`new(MyStruct)` 和 `&MyStruct{}` 在功能上是等价的，都返回一个指向零值结构体的指针。但在编码习惯上，当不需要在创建时初始化特定字段（即所有字段都使用零值）时，两者皆可；若需要在创建时初始化特定字段，则必须使用复合字面量 `&MyStruct{Field: value}`。直接用字面量语法创建结构体变量的方法更灵活，new 函数通常使用较少。

---

new 与 make 的区别：

| 特性 | `new(T)` | `make(T, ...)` |
| -- | -- | -- |
| 适用类型 | 任意类型 T | 仅限切片、映射、通道三种引用类型 |
| 返回类型 | `*T`（指向值为 T 类型零值变量的指针） | `T`（初始化后的值本身，非指针） |
