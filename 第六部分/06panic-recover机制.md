# panic-recover 机制

数组访问越界、空指针解引用等运行时错误会引发 panic。但不是所有的 panic 都来自运行时，直接调用内置函数 [func panic(v any)](https://pkg.go.dev/builtin#panic) 也会引发 panic，`panic()` 函数接受任何值作为参数。

```go
func main() {
 s := []int{1, 2, 3}
 s[3] = 1 // 索引 3 超出范围，会引发 panic

 var p *int
 fmt.Println(*p) // 对 nil 指针解引用，会引发 panic
}
```

内置函数 [func recover() any](https://pkg.go.dev/builtin#recover) 的作用是捕获 panic，恢复协程的执行。`recover()` 的返回值就是传给 `panic()` 的参数。如果没有发生 panic，`recover()` 返回 nil。注意：`recover()` 仅在被 defer 的函数体中有效，如果 `recover()` 不在被 defer 的函数体中，则不会捕获任何 panic。

发生 panic 后，会立即中断当前函数的执行，按 LIFO 执行当前函数的 defer 列表。如果某个被 defer 的函数体中有 `recover()`，当前函数执行完 defer 列表后直接返回（不会继续执行 panic 发生点之后的代码，返回非命名返回值类型的零值或命名返回值的值），调用当前函数的上层函数会从调用点之后继续执行；否则，当前函数执行完 defer 列表后，继续将 panic 向上传播给它的调用者，如果传播到当前协程的调用栈顶仍没有 `recover()` 则整个程序崩溃。

基本示例：

```go
func main() {
 defer func() {
  fmt.Println("1")
 }()

 defer func() {
  fmt.Println("2")
  if r := recover(); r != nil {
   fmt.Printf("recovered from panic, err: %v\n", r) // recovered from panic, err: something went wrong
  }
 }()

 defer func() {
  fmt.Println("3")
 }()

 fmt.Println("start")
 panic("something went wrong")           // 传递给 panic() 的值是 "something went wrong"，recover() 将返回这个值
 fmt.Println("this will not be printed") // 这一行不会执行，panic 发生点之后的代码不会执行
}

// start
// 3
// 2
// recovered from panic, err: something went wrong
// 1
```

`recover()` 仅在被 defer 的函数体中有效，不在被 defer 的函数体中则不会捕获任何 panic：

```go
func f() {
 if r := recover(); r != nil { // 无效！不会捕获任何 panic
  fmt.Printf("recovered from panic, err: %v\n", r)
 }
 panic("test")
}

func main() {
 fmt.Println(1) // 1
 f()            // f() 中发生 panic，且 f() 的 defer 列表中没有 recover()，main() 也无 defer 列表，整个程序崩溃
 fmt.Println(2)
}
```

注意：某些致命错误会导致 Go 运行时终止程序，如栈溢出、内存耗尽等，这些是 fatal error 而非普通 panic，recover 也捕获不到，程序必然崩溃。

## panic 的传播与覆盖

对于发生 panic 的函数，panic 发生点之后的代码不会继续执行，控制权会返回到它的调用方。如果函数 f() 中发生的 panic 向上传播给它的调用者 g()，g() 的某个 defer 中的 `recover()` 捕获了这个 panic，g() 中位于 `f()` 调用之后的代码也不会继续执行，因为在 g() 看来，调用 `f()` 的地方就是 panic 发生点。

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
 defer func() { // main() 的 defer 列表中有 recover()，所以执行完 defer 列表后，main() 函数返回，程序不会崩溃。如果 main() 的 defer 列表中没有 recover()，程序就会崩溃
  if r := recover(); r != nil { // recover() 的返回值就是传给 panic() 的参数
   fmt.Printf("recovered from panic in main, err: %v\n", r)
  }
 }()

 a()                    // 调用 a，a() 的 defer 列表中没有 recover，所以 panic 会传递给 main()，这一行调用 a() 的地方就是 panic 发生点，其后的代码不会执行
 fmt.Println("after a") // 不会执行
}

// in a
// in b
// defer in b
// defer in a
// recovered in main: panic in b
```

发生 panic P1 后，如果执行的 defer 函数 `f()` 内部又触发了新的 panic P2，那么新的 panic P2 会替代先前的 panic P1，成为当前正在传播的 panic。应当在函数 `f()` 内部增加 defer 函数调用来 recover 掉这个新的 panic P2，而不是让 panic P2 覆盖 panic P1。

```go
func main() {
 defer func() {
  if r := recover(); r != nil { // 多次 panic，recover 捕获的是最后一次 panic 的值
   fmt.Printf("1 recovered from panic, err: %v\n", r)
  }
 }()

 defer func() {
  // 如果注释掉下面这段 defer 代码，最终打印的就是“1 recovered from panic, err: inner panic”，可以看到“inner panic”覆盖了“outer panic”，成为当前正在传播的 panic
  defer func() {
   if r := recover(); r != nil { // recover() 捕获了新产生的“inner panic”，防止它覆盖“outer panic”
    fmt.Printf("2 recovered from panic, err: %v\n", r) // 第 5 步
   }
  }()

  fmt.Println("inner panic") // 第 3 步
  panic("inner panic")       // 第 4 步，一个正在执行的 defer 函数体中又触发了新的 panic
 }()

 fmt.Println("outer panic") // 第 1 步
 panic("outer panic")       // 第 2 步
}

// outer panic
// inner panic
// 2 recovered from panic, err: inner panic
// 1 recovered from panic, err: outer panic
```

以下程序最终崩溃的原因是外层的 `panic("outer panic")` 没有被其所在函数以及上层函数的任何 `recover()` 捕获。虽然内层的 panic 被成功恢复，但这并不影响外层 panic 向上传播。

```go
func main() {
 defer func() {
  defer func() {
   if r := recover(); r != nil {
    fmt.Printf("recovered from panic, err: %v\n", r) // 第 5 步
   }
  }()
  fmt.Println("inner panic") // 第 3 步
  panic("inner panic")       // 第 4 步
 }()
 fmt.Println("outer panic") // 第 1 步
 panic("outer panic")       // 第 2 步
}

// outer panic
// inner panic
// recovered from panic, err: inner panic
// panic: outer panic

// goroutine 1 [running]:
// main.main()
//         /home/hardy/workspace/test/go/hello-world/main.go:16 +0x78
// exit status 2
```

被 defer 的函数体应保持简单，只做资源清理、状态还原等不会 panic 的操作，避免在其中触发新的 panic。

## 协程之间的 panic-recover

不同协程之间是独立执行的，一个协程的 `recover()` 无法捕获另一个协程的 panic。

如果一个协程发生 panic 且未被捕获，会导致整个程序崩溃，而不仅仅是这个协程退出，这是 Go 的设计哲学。因此，协程内部必须捕获 panic 以防止整个程序崩溃。

示例 1：在协程内部的 `recover()` 可以捕获其中的 panic，程序不会崩溃：

```go
func main() {
 var wg sync.WaitGroup

 wg.Go(func() {
  // 在协程内部 recover()，程序不会崩溃
  defer func() {
   if r := recover(); r != nil {
    fmt.Printf("recovered from panic, err: %v\n", r)
   }
  }()

  panic("协程 panic")
 })

 wg.Wait()
 fmt.Printf("main() continued\n")
}

// recovered from panic, err: 协程 panic
// main() continued
```

示例 2：在 main 协程中的 `recover()` 无法捕获其它协程中的 panic，程序会崩溃：

```go
func main() {
 var wg sync.WaitGroup

 defer func() {
  // 这个 recover() 只能捕获 main 协程中的 panic
  // 无法捕获下面启动的协程中的 panic
  if r := recover(); r != nil {
   fmt.Printf("recovered from panic, err: %v\n", r)
  }
 }()

 wg.Go(func() {
  panic("协程 panic") // 这个 panic 不会被上面的 recover() 捕获，因为是不同的协程
 })

 wg.Wait()
}
```

## safeCall

在要执行的函数外包一层 `safeCall`，捕获函数中可能的 panic，避免程序崩溃：

```go
func safeCall(fn func()) {
 defer func() {
  if r := recover(); r != nil {
   fmt.Printf("recovered from panic, err: %v\n", r)
   // 可以在这里进行错误上报等操作
  }
 }()
 fn()
}

func main() {
 safeCall(func() { // 函数可能 panic，在外面包装一层，捕获 panic 并恢复执行
  fmt.Println("start")
  panic("test panic")
  fmt.Println("this line will not be executed") // 就算 recover 了，也不会执行到这一行，但匿名函数调用能正常返回
 })
 // 后续代码会继续执行
 fmt.Println("program continues")
}
```

## 注意事项

在实际开发中应当限制直接调用 `panic()`，panic-recover 机制不是错误处理策略。

- 仅在真正不可恢复的错误场景才使用 `panic()`
- 在库/框架中避免调用 `panic()`，返回 error 更常见
- 即使在测试代码中，也优先使用 `t.Fatal()` 或者 `t.FailNow()` 而不是 `panic()`
