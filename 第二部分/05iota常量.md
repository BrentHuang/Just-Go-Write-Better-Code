
# iota 常量

iota 是一个预定义的常量，用于简化枚举和相关常量的定义，只能用在常量分组声明中。

```go
const iota = 0 // Untyped int.
```

核心机制：

- 从零开始：const 声明块中 iota 初始值为 0
- 逐行递增：每增加一行，iota 自动加 1，可理解为 iota 是 const 声明块中的行索引
- 值/表达式继承：未显式赋值的常量将继承上一个常量的值/表达式，但其中的 iota 会更新为当前行的索引
- 重置归零：一旦遇到新的 const 声明，iota 即被重置为 0

| 用法分类 | 代码示例 | 常量值说明 | 核心要点 |
| -- | -- | -- | -- |
| 基础递增 | const (<br> A = iota<br> B<br> C<br> ) | `A=0, B=1, C=2` | 最基本的自动递增，从 0 开始的行索引 |
| iota 表达式 | const (<br> A = iota * 2<br> B<br> C<br> ) | `A=0, B=2, C=4` | B、C 继承 `iota * 2` 表达式 |
| 跳过值 | const (<br> A = iota<br> _<br> B<br> ) | `A=0, B=2` | 使用空白标识符 `_` 跳过特定值，iota 计数不会因插入其它值而中断 |
| 从 1 开始 | const (<br> _ = iota<br> Red<br> Green<br> ) | `Red=1, Green=2` | 跳过 0，从 1 开始计数 |
| 中间插入显式值 | const (<br> A = iota<br> B = 100<br> C = iota<br> D<br> ) | `A=0, B=100, C=2, D=3` | iota 计数不会因插入其它值而中断 |
| 一行多个常量 | const (<br> A, B = iota, iota+1<br> C, D<br> ) | `A=0, B=1, C=1, D=2` | 同一行 iota 值相同，后续行中的多个常量分别继承对应的表达式 |

```go
func main() {
 const (
  A = iota     // iota = 0
  B = 100      // B 被显式设置为 100，iota 递增到 1
  C            // C 没有显式赋值，它会继承 B 的值，即 100
  D = iota * 2 // iota = 3（因为这是 const 块中的第 4 行，行索引为 3），D 的值为 6
  E            // E 继承 D 的表达式，iota = 4，E 的值为 8
  F            // F 继承 D 的表达式，iota = 5，F 的值为 10
 )

 fmt.Printf("%d %d %d %d %d %d\n", A, B, C, D, E, F)  // 0 100 100 6 8 10

 const x = iota // 遇到新的 const 声明，iota 被重置为 0
 fmt.Println(x)  // 0
}
```

## 枚举

Go 没有枚举类型，定义整型枚举的标准步骤是：

1. 声明一个自定义类型
2. 分组声明使用 iota 的一组常量

```go
// 1. 自定义类型
type Weekday int

// 2. 分组声明使用 iota 的一组常量
const (
 Sunday Weekday = iota // iota 常量生成器
 Monday
 Tuesday
 Wednesday
 Thursday
 Friday
 Saturday
)

// 实现 fmt.Stringer 接口，返回对应的字符串表示
func (d Weekday) String() string {
 return [...]string{"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}[d] // 这里的 ... 表示根据初始化值自动推导数组长度
}

func main() {
 today := Tuesday
 fmt.Printf("today is %v (%d)\n", today, today)  // today is Tuesday (2)
}
```

字符串类型的枚举：

```go
// 1. 自定义类型
type Color string

// 2. 分组声明
const (
 Red   Color = "red"
 Green Color = "green"
 Blue  Color = "blue"
)

func main() {
 color := Red

 switch color {
 case Red:
  fmt.Println("这是红色")
 case Green:
  fmt.Println("这是绿色")
 case Blue:
  fmt.Println("这是蓝色")
 default:
  fmt.Println("未知颜色")
 }
}
```

## 位域

Go 没有像 C/C++ 那样的直接位域（bit field）语法，最惯用的实现方式是使用无符号整数和 iota 位掩码手动管理位域。

```go
// 1. 定义类型安全的位域类型
type Permissions uint8

// 2. 使用 iota 生成位掩码，这是最标准的做法
const (
 FlagRead    Permissions = 1 << iota // 0000 0001 = 1
 FlagWrite                           // 0000 0010 = 2
 FlagExecute                         // 0000 0100 = 4
 FlagDelete                          // 0000 1000 = 8
 FlagShare                           // 0001 0000 = 16
)

// 标准方法集
func (p Permissions) Has(flag Permissions) bool {
 return p&flag != 0
}

func (p *Permissions) Set(flag Permissions) {
 *p |= flag
}

func (p *Permissions) Clear(flag Permissions) {
 *p &^= flag
}

// 通过异或运算翻转指定位：构造一个掩码（mask），将希望翻转的位设为 1，其余位设为 0，然后与原数进行异或
func (p *Permissions) Toggle(flag Permissions) {
 *p ^= flag
}

// 实现 fmt.Stringer 接口
func (p Permissions) String() string {
 var flags []string
 if p.Has(FlagRead) {
  flags = append(flags, "READ")
 }
 if p.Has(FlagWrite) {
  flags = append(flags, "WRITE")
 }
 if p.Has(FlagExecute) {
  flags = append(flags, "EXECUTE")
 }
 if p.Has(FlagDelete) {
  flags = append(flags, "DELETE")
 }
 if p.Has(FlagShare) {
  flags = append(flags, "SHARE")
 }
 return fmt.Sprint(flags)
}

func main() {
 var perms Permissions

 // 设置权限
 perms.Set(FlagRead)
 perms.Set(FlagWrite)
 perms.Set(FlagExecute)

 fmt.Printf("权限: %s\n", perms.String()) // 权限：[READ WRITE EXECUTE]
 fmt.Printf("二进制：%08b\n", perms)        // 二进制：00000111

 // 检查权限
 fmt.Printf("可读：%t\n", perms.Has(FlagRead))   // 可读：true
 fmt.Printf("可删：%t\n", perms.Has(FlagDelete)) // 可删：false

 // 切换权限
 perms.Toggle(FlagWrite)
 fmt.Printf("切换写权限后: %s\n", perms.String()) // 切换写权限后：[READ EXECUTE]
}
```
