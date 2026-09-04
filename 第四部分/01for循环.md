# for 循环

Go 只有一种循环结构，即 for 循环，没有 `do-while`、`while` 循环。完整三段式语法：

```go
for 初始化语句; 条件表达式; 后置语句 {
    // 循环体
}
```

for 循环的初始化语句通常是一个短变量声明（`:=`），声明的变量仅在 for 循环中有效。当条件表达式为 false 时停止循环。

与 C、JavaScript 不同，Go 的 for 循环的三个构成部分外面不加小括号，但循环体必须加大括号。

```go
func main() {
 sum := 0
 for i := 0; i < 10; i++ { // i 从 0 到 9
  fmt.Printf("%v, %p\n", i, &i) // 注意：每次循环中 i 的地址都不同，是不同的变量（Go 1.22+）
  sum += i                      // 变量 i 仅在 for 循环体中有效
 }
}
```

Go 1.22 引入了 `range` 迭代整数的语法：`range n` 表示从 0 迭代到 n-1，支持省略循环变量。

```go
func main() {
 sum := 0
 for i := range 10 { // i 从 0 到 9
  fmt.Printf("%v, %p\n", i, &i) // 注意：每次循环中 i 的地址都不同，是不同的变量（Go 1.22+）
  sum += i
 }

 // 不使用循环变量 i 时可以省略
 for range 10 { // 循环 10 次
 }
}
```

> [!IMPORTANT]
> 从 Go 1.22 开始，for 循环的变量在每次迭代时都会创建新变量（而非共享同一变量）。这意味着在循环体中取循环变量的地址是安全的，不再需要通过临时变量来捕获值。

`range` 还可用于遍历字符串、数组、切片、映射、通道等集合类型，后续章节将详细介绍。

## “while”循环

for 循环的“初始化语句”和“后置语句”都是可选的，仅剩”条件表达式“时就变成了“while”语句，此时两个分号都可省略：

```go
func main() {
 sum := 1
 for sum < 1000 { // 仅剩条件表达式，两个分号都省略
  sum += sum
 }
}
```

## 无限循环

当三个构成部分均省略时，就变成了无限循环，等价于 C 语言的 `for (;;)`：

```go
func main() {
 for { // 三个构成部分全无，就变成了无限循环
  // ...
 }
}
```

## break、continue 及标签

for 循环体中可以使用 `break` 和 `continue` 控制循环流程：

- `break`：立即终止当前最内层循环，继续执行循环后的代码
- `continue`：跳过当前迭代的剩余代码，直接进入下一次迭代

```go
func main() {
 for i := range 10 {
  if i%2 == 0 {
   continue // 跳过偶数，进入下一次迭代
  }
  fmt.Println(i) // 仅打印奇数：1, 3, 5, 7, 9
 }
}
```

```go
func main() {
 for i := range 10 {
  if i == 5 {
   break // 当 i 等于 5 时终止循环
  }
  fmt.Println(i) // 打印 0, 1, 2, 3, 4
 }
}
```

在嵌套循环中，`break` 和 `continue` 默认只作用于最内层循环。若需控制外层循环，可配合标签（label）使用，标签命名通常采用首字母大写驼峰法（CamelCase）：

```go
func main() {
RowLoop:  // label 命名采用首字母大写驼峰法。此处的 label 名称应体现外层循环的职责
 for i := range 10 {
  for j := range 5 {
   fmt.Printf("%d %d\n", i, j)

   if j == 3 {
    break RowLoop // 退出 label 标识的循环
   }
  }
 }
}
```

```go
func main() {
RowLoop:
 for i := range 10 {
  for j := range 5 {
   fmt.Printf("%d %d\n", i, j)

   if j == 3 {
    continue RowLoop // 继续 label 标识的循环的下一次迭代
   }
  }
 }
}
```

注意：

- 标签名应能清晰地表达其控制的代码段的职责，而非仅描述其位置（如 Outer）
- 标签的作用域被限定在定义它的函数体中，无法跨函数使用。在同一函数体中，标签名必须唯一，不能与变量、类型等其它标识符同名
- 标签必须紧贴在目标语句之前，中间不能有变量声明等代码

标签还可用于 `goto` 语句，详见下一节。
