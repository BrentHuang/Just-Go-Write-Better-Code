# if-else 语句

语法：

```go
// autocorrect-disable
if 条件表达式1 {
 // 条件1 为 true 时执行
} else if 条件表达式2 {
 // 条件2 为 true 时执行
} else {
 // 其它情况执行
}
// autocorrect-enable
```

与 for 循环一样，条件表达式外面不加小括号，但代码块必须加大括号。

Go 的 if 条件表达式必须是 bool 类型，这与 C 等语言不同（在这些语言中，非零整数可作为真值）：

```go
func main() {
 if 1 {  // 编译报错，必须是 bool 条件表达式
  fmt.Println("hello")
 }
}
```

## 初始化语句

允许在 if 的“条件表达式”之前执行一个简短的初始化语句，在此处声明的变量仅在 if-else 代码块中有效。

```go
if 初始化语句; 条件表达式 {
 // 代码块
}
```

```go
func pow(x, n, lim float64) float64 {
 // v 仅在 if-else 代码块中有效
 if v := math.Pow(x, n); v < lim {  // Pow 返回 x**y，即 x 的 y 次幂
  return v
 } else {
  // %g 是浮点数的通用格式化动词，会根据数值大小自动选择 %f 或 %e，并省略不必要的尾随零
  fmt.Printf("%g >= %g\n", v, lim)
 }

 // v 在这里无效了
 _ = v // 编译报错

 return lim
}
```

## 条件书写原则

if-else 条件的书写原则：

- 安全第一：`nil` 检查、数组越界、除零等防御性条件必须优先
- 廉价优先：利用 `&&`、`||` 的短路特性，将布尔值、整数比较等低开销条件放在前面，避免执行昂贵计算
- 概率优先：在满足前两条的前提下，将命中率最高的热路径放在前面，以减少平均比较次数，且有助于 CPU 分支预测

## 常见使用场景

错误处理：

```go
if err := doSomething(); err != nil {
 fmt.Printf("发生错误：%v\n", err)
}
```

映射（map）取值检查：

```go
if val, ok := m["key"]; ok {
 fmt.Printf("找到值：%v\n", val)
}
```

类型断言（type assertion）：

```go
if s, ok := val.(string); ok {
 fmt.Printf("val 是字符串：%s\n", s)
}
```
