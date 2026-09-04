# switch 语句

switch 语句从上到下检查 case，执行第一个与 switch 匹配的 case 代码块。语法：

```go
switch 表达式/值 {
case 表达式1/值1:
    // 代码块，不需要加大括号
case 表达式2/值2, 表达式3/值3: // 逗号分隔，或的关系
    // 多个值匹配同一个代码块
case 表达式4/值4:
    // 允许代码块为空
default:
    // 默认代码块
}
```

注意：

- case 代码块不需要加大括号（可以加，没必要），一个 case 可以匹配多个值，用逗号分隔。Go 中的 case 允许空语句，表示“这个条件满足后什么都不做”，而不是与下一个 case 共用逻辑
- 每个 case 代码块的结尾不需要加 break（可以加，没必要），Go 执行完一个 case 块后就会退出 switch，相当于在每个 case 块的结尾自动加了 break。在代码块中间的 break 会提前结束当前的 case
- 一个 switch 语句最多只能有一个 default 分支，可以没有 default 分支

```go
func main() {
 a := 1
 switch a {
 case 1:
  fmt.Println("xxx")
  break              // 在 case 块结尾加不加 break 都一样，在中间的 break 可以提前结束 case 块
  fmt.Println("yyy") // 前面的 break 会提前结束 case 块，所以这里不会执行
 default:
  fmt.Println("zzz")
 }
}
```

case 值不必为常量，可以为变量、表达式、函数调用返回值，这在需要动态判断时非常有用。

```go
func main() {
 dynamicValue := rand.IntN(10) // 生成一个随机数作为动态值（rand.IntN 来自 math/rand/v2，Go 1.22 引入）
 valueToCompare := 5

 switch dynamicValue { // switch 表达式是一个变量
 case valueToCompare: // case 值也是一个变量
  fmt.Printf("dynamicValue 等于 %d\n", valueToCompare)
 case valueToCompare + 1, valueToCompare + 2: // case 值也可以是表达式
  fmt.Printf("dynamicValue 是 %d 或 %d\n", valueToCompare+1, valueToCompare+2)
 default:
  fmt.Printf("dynamicValue 是 %d，与 case 条件都不匹配\n", dynamicValue)
 }
}
```

允许 switch 是值，case 是表达式。switch 和 case 的本质是比较操作，表达式或值放在哪一侧均可。

示例 1:

```go
func main() {
 fmt.Println("When's Saturday?")
 today := time.Now().Weekday()
 switch time.Saturday {  // 值
 case today + 0:  // 表达式 1
  fmt.Println("Today.")
 case today + 1:  // 表达式 2
  fmt.Println("Tomorrow.")
 case today + 2:  // 表达式 3
  fmt.Println("In two days.")
 default:  // default
  fmt.Println("Too far away.")
 }
}
```

示例 2:

```go
func main() {
 a := 0
 b := 2

 switch a + 4 { // 表达式
 case b + 1: // 表达式 1
  fmt.Println("3")
 case b + 2: // 表达式 2
  fmt.Println("4") // 4
 default:
  fmt.Println("unknown")
 }
}
```

## 初始化语句

switch 语句也允许在表达式之前执行一个简短的初始化语句，在此处声明的变量仅在 switch-case 代码块中有效。

```go
func main() {
 // os 仅在 switch-case 代码块中有效
 switch os := runtime.GOOS; os {  // 在表达式之前执行初始化语句
 case "linux":  // 值 1
  fmt.Println("Linux")
 case "windows":  // 值 2
  fmt.Println("Windows")
 case "darwin":  // 值 3
  fmt.Println("macOS")
 default:  // default
  fmt.Println(os)
 }
 // os 在这里就无效了
 fmt.Println(os) // 编译报错
}
```

## switch true

当 switch 后不跟任何表达式/值时（等同于 `switch true`），每个 case 条件都应该是布尔表达式。这种语法可以用来替代冗长的 `if-else if` 链，让代码更清晰。

```go
func main() {
 t := time.Now()
 h := t.Hour()

 // 这个 switch 等价于下面的 if-else if
 switch {
 case h < 12:  // if h < 12
  println("Good morning")
 case h < 18:  // else if h < 18
  println("Good afternoon")
 default:  // else
  println("Good evening")
 }

 if h < 12 {
  println("Good morning")
 } else if h < 18 {
  println("Good afternoon")
 } else {
  println("Good evening")
 }
}
```

## fallthrough 显式穿透

仅当 case 代码块的结尾使用 fallthrough 关键字时，才会继续执行下一个相邻的 case 或 default 代码块，不管下一个 case 的表达式/值是否与 switch 匹配。

仅能穿透下一个相邻的 case 或 default，不会连续穿透。

fallthrough 不能出现在 switch 的最后一个 case 或 default 中（编译报错），因为没有下一个相邻的 case 或 default 可以穿透了。

```go
func main() {
 n := 2
 switch n {
 case 1:
  fmt.Println("Case 1")
 case 2:
  fmt.Println("Case 2")  // 输出 Case 2
  fallthrough            // 穿透到 case 3
 case 3:
  fmt.Println("Case 3")  // 输出 Case 3（即使 n=2 不匹配 case 3）
  fallthrough            // 穿透到 case 4
 case 4:
  fmt.Println("Case 4")  // 输出 Case 4
 }
}
```

fallthrough 不能用在类型选择（type switch）中，因为 type switch 按具体类型匹配，一个值只会命中其中一个 case，穿透到下一个 case 没有意义。类型选择的详细用法将在后续章节介绍。

## 其他可比较类型

除整型外，switch 可以处理各种可比较的类型，字符串是最常见的非整数应用场景之一。

```go
func main() {
 fruit := "apple"

 switch fruit { // switch 表达式是字符串类型
 case "apple":
  fmt.Println("apple")
 case "banana", "mango": // 一个 case 可以对应多个值
  fmt.Println("banana or mango")
 default:
  fmt.Println("unknown")
 }

 // 浮点数，但需注意精度问题：浮点数使用 == 比较可能因精度误差导致意外结果，实际项目中应避免直接比较浮点数
 ratio := 3.14
 switch ratio {
 case 3.14:
  fmt.Println("约等于 π")
 case 1.41:
  fmt.Println("约等于 √2")
 }
}
```
