# goto 语句

goto 允许无条件跳转到同一函数体中的指定标签。注意：

1. 只能在同一函数体中跳转，不能跨函数
2. 不能跳过变量声明，编译报错
3. 不能跳入代码块内部，编译报错

> [!WARNING]
> `goto` 在实际项目中极少使用，通常被认为是代码坏味道。大多数场景下，可通过函数拆分、`defer`、`break`/`continue` 等方式替代。少数合法使用场景包括：在多层嵌套循环中统一跳出、或在复杂错误处理中跳转到资源清理代码。

```go
func main() {
 goto Skip // 编译报错，跳过了 x 的声明
 x := 10
Skip:
 fmt.Println(x)
}
```

```go
func main() {
 goto Block // 编译报错，跳入了代码块内部
 {
 Block:
  fmt.Println("内部")
 }
}
```
