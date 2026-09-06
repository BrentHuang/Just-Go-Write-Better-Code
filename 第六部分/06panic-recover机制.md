## panic-recover 机制

函数原型：

```go
func panic(v any)
func recover() any
```

`recover()` 的返回值就是传给 `panic()` 的参数。如果没有发生 panic，`recover()` 返回 nil。

数组访问越界、空指针引用等运行时错误会引发 panic。但不是所有的 panic 都来自运行时，直接调用内置的 `panic()` 函数也会引发 panic，`panic()` 函数接受任何值作为参数。

`recover()` 的作用是捕获 panic，恢复程序的执行。其特点包括：

- `recover()` 仅在被 defer 的函数体中有效，如果 `recover()` 不在被 defer 的函数体中，则不会捕获任何 panic
- 发生 panic 后，会立即中断当前函数的执行，按 LIFO 执行当前函数的 defer 列表。如果某个被 defer 的函数体中有 `recover()`，当前函数执行完 defer 列表后直接返回（不会继续执行 panic 发生点之后的代码），调用当前函数的上层函数会从调用点之后继续执行；否则，当前函数执行完 defer 列表后，继续将 panic 向上传播给它的调用者，如果传播到 `main()` 仍没有 `recover()` 则程序崩溃
- 对于发生 panic 的函数，panic 发生点之后的代码不会继续执行，控制权会返回到它的调用方。如果函数 A 中发生的 panic 向上传播给它的调用者 B，B 的某个 defer 中的 `recover()` 捕获了这个 panic，B 中位于 `A()` 调用之后的代码也不会继续执行，因为调用 `A()` 的地方就是 panic 发生点
- 发生 panic P 后，如果执行的 defer 函数 f 内部又触发了新的 panic Q，那么新的 panic Q 会替代先前的 panic P，成为当前正在传播的 panic。应当在函数 f 内部增加 defer 函数调用来 recover 这个新的 panic Q，而不是让 panic Q 覆盖 panic P

基本示例：

```go
func main() {
 defer func() {
  fmt.Println("1")
 }()

 defer func() {
  if r := recover(); r != nil {
   fmt.Printf("Recovered from panic, err: %v\n", r) // 输出：Recovered: something went wrong
  }
 }()

 defer func() {
  fmt.Println("2")
 }()

 fmt.Println("Start")
 panic("something went wrong")           // 传递给 panic() 的值是 "something went wrong"，recover() 将返回这个值
 fmt.Println("This will not be printed") // panic 发生点之后的代码不会执行，main() 函数能正常返回
}

// 输出：
// Start
// 2
// Recovered: something went wrong
// 1 // 这里输出 1 的原因：会执行完 defer 列表，执行完 defer 列表后再返回
```

`recover()` 仅在被 defer 的函数体中有效，不在被 defer 的函数体中则不会捕获任何 panic：

```go
func f() {
 if r := recover(); r != nil { // 无效！不会捕获任何 panic
  fmt.Printf("Recovered from panic, err: %v\n", r)
 }
 panic("test")
}

func main() {
 fmt.Println(1) // 1
 f()            // f() 中发生 panic，且 f 的 defer 列表中没有 recover(),main() 无 defer 列表，程序崩溃
 fmt.Println(2)
}
```

### panic 的传播与覆盖

多层函数调用的 defer-recover 链：

```go

func a() {
 defer fmt.Println("defer in a") // a() 的 defer 列表中没有 recover()，所以执行完 defer 列表后，a() 调用返回，panic 会继续向上传播给 main()
 fmt.Println("in a")
 b()                    // b() 中会 panic，且 b() 的 defer 列表中没有 recover()，所以 panic 会继续向上传播给 a()，这一行调用 b() 的地方就是 panic 发生点，其后的代码不会执行
 fmt.Println("after b") // 不会执行
}

func b() {
 defer fmt.Println("defer in b") // b() 的 defer 列表中没有 recover()，所以执行完 defer 列表后，b() 调用返回，panic 会继续向上传播给 a()
 fmt.Println("in b")
 panic("panic in b")        // panic 发生点，其后的代码不会执行
 fmt.Println("after panic") // 不会执行
}

func main() {
 defer func() { // main() 的 defer 列表中有 recover()，所以执行完 defer 列表后，main() 调用返回，panic 恢复，程序不会崩溃。如果 main() 的 defer 列表中没有 recover()，程序就会崩溃
  if r := recover(); r != nil { // recover() 的返回值就是传给 panic() 的参数
   fmt.Printf("Recovered from panic in main, err: %v\n", r)
  }
 }()

 a()                    // 调用 a，a() 的 defer 列表中没有 recover，所以 panic 会传递给 main()，这一行调用 a() 的地方就是 panic 发生点，其后的代码不会执行
 fmt.Println("after a") // 不会执行
}

// 输出：
// in a
// in b
// defer in b
// defer in a
// Recovered in main: panic in b
```

注意：某些致命错误会导致 Go 运行时终止程序，如内存不足，这些情况是无法恢复的。

以下程序最终崩溃的原因是外层的 `panic("outer panic")` 没有被本层函数以及上层函数的任何 `recover()` 捕获。虽然内层的 panic 被成功恢复，但这并不影响外层 panic 向上传播。

```go
func main() {
 defer func() {
  defer func() {
   if r := recover(); r != nil {
    fmt.Printf("inner recovered from panic, err: %v\n", r) // 第 5 步
   }
  }()
  fmt.Println("inner panic") // 第 3 步
  panic("inner panic")       // 第 4 步
 }()
 fmt.Println("outer panic") // 第 1 步
 panic("outer panic")       // 第 2 步
}

// 输出：
// outer panic
// inner panic
// inner recover err inner panic
// panic: outer panic

// goroutine 1 [running]:
// main.main()
//         /home/hardy/workspace/test/go/hello2/main.go:16 +0x78
// exit status 2
```

defer 应只做清理、可预测的操作，尽量不要在被 defer 的函数体中触发新的 panic。如果被 defer 的函数体中有可能 panic，应当在这个被 defer 的函数体中增加 defer 函数调用 `recover()` 这个新的 panic，否则它将替代先前的 panic，成为当前正在传播的 panic。

```go
func main() {
 defer func() {
  if r := recover(); r != nil { // 多次 panic，recover 捕获的时最后一次 panic 的值
   fmt.Printf("main recover: %v\n", r)
  }
 }()

 defer func() {
  // 如果注释掉下面这段 defer 代码，最终打印的就是 main recover: inner panic，可以看到“inner panic”覆盖了“outer panic”，成为当前正在传播的 panic
  defer func() {
   if r := recover(); r != nil { // recover() 捕获了新产生的“inner panic”，防止它覆盖“outter panic”
    fmt.Printf("inner recover: %v\n", r) // 第 5 步
   }
  }()

  fmt.Println("inner panic") // 第 3 步
  panic("inner panic")       // 第 4 步，一个正在执行的 defer 函数体中又触发了新的 panic
 }()

 fmt.Println("outer panic") // 第 1 步
 panic("outer panic")       // 第 2 步
}

// 输出：
// outer panic
// inner panic
// inner recover: inner panic
// main recover: outer panic
```

### Goroutine 之间的 panic-recover

不同 Goroutine 之间是独立执行的，一个 Goroutine 的 `recover()` 无法捕获另一个 Goroutine 的 panic。

如果一个 Goroutine 发生 panic 且未被捕获，会导致整个程序崩溃，而不仅仅是这个 Goroutine 退出。因此，Goroutine 内部必须捕获 panic 防止整个进程崩溃。

示例 1：在 Goroutine 内部的 `recover()` 可以捕获其中的 panic，程序不会崩溃：

```go
func main() {
 var wg sync.WaitGroup

 wg.Go(func() {
  // 在 Goroutine 内部 recover()，程序不会崩溃
  defer func() {
   if r := recover(); r != nil {
    fmt.Printf("recovered: %v\n", r)
   }
  }()

  panic("Goroutine 出错")
 })

 wg.Wait()
 fmt.Printf("main() continued\n")
}

// 输出：
// recovered: Goroutine 出错
// main() continued
```

示例 2：在 main Goroutine 中的 `recover()` 无法捕获子 Goroutine 中的 panic，程序会崩溃：

```go
func main() {
 var wg sync.WaitGroup

 defer func() {
  // 这个 recover() 只能捕获 main Goroutine 的 panic
  // 无法捕获下面启动的子 Goroutine 的 panic
  if r := recover(); r != nil {
   fmt.Printf("recovered: %v", r)
  }
 }()

 wg.Go(func() {
  panic("Goroutine 出错") // 这个 panic 不会被上面的 recover() 捕获，因为是不同的 Goroutine
 })

 wg.Wait()
}
```

### 注意事项

在实际开发中应当限制直接调用 `panic()`，panic-recover 机制不是错误处理策略。

- 仅在真正不可恢复的错误场景才使用 `panic()`
- 在库/框架中避免调用 `panic()`，返回 error 更常见
- 即使在测试代码中，也优先使用 `t.Fatal()` 或者 `t.FailNow()` 而不是 `panic()`
